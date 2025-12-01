const { createPublicClient, http, encodeFunctionData, parseEther, toHex } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { base } = require('viem/chains');

const ACCOUNT_V6 = "0x8DD4dA660F08C93E26db953CfbCef8516b2DE101";
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
const NOVIS = "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6";
const RECIPIENT = "0x685F3040003E20Bf09488C8B9354913a00627f7a";

const account = privateKeyToAccount(process.env.PRIVATE_KEY);

const publicClient = createPublicClient({
  chain: base,
  transport: http(process.env.BASE_RPC_URL)
});

const bundlerClient = createPublicClient({
  chain: base,
  transport: http(process.env.PIMLICO_BUNDLER_URL)
});

async function testBundler() {
  console.log("🚀 Testing V6 account with Pimlico bundler...\n");
  
  // Build transfer calldata (encodeFunctionData already includes selector!)
  const transferData = encodeFunctionData({
    abi: [{ name: 'transfer', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ type: 'bool' }] }],
    functionName: 'transfer',
    args: [RECIPIENT, parseEther('0.1')]
  });
  
  // Build execute calldata
  const callData = encodeFunctionData({
    abi: [{ name: 'execute', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }], outputs: [{ type: 'bytes' }] }],
    functionName: 'execute',
    args: [NOVIS, 0n, transferData]
  });
  
  const feeData = await publicClient.estimateFeesPerGas();
  
  const userOp = {
    sender: ACCOUNT_V6,
    nonce: toHex(0n),
    initCode: '0x',
    callData: callData,
    callGasLimit: toHex(300000n),
    verificationGasLimit: toHex(300000n),
    preVerificationGas: toHex(100000n),
    maxFeePerGas: toHex(feeData.maxFeePerGas),
    maxPriorityFeePerGas: toHex(feeData.maxPriorityFeePerGas || 1000000n),
    paymasterAndData: '0x',
    signature: '0x'
  };
  
  console.log("✅ UserOp built");
  console.log("🔄 Requesting Pimlico sponsorship...\n");
  
  try {
    const sponsorResult = await bundlerClient.request({
      method: 'pm_sponsorUserOperation',
      params: [userOp, { entryPoint: ENTRYPOINT }]
    });
    
    console.log("🎉 SPONSORSHIP APPROVED!");
    console.log("   Paymaster will pay gas!");
    console.log("   paymasterAndData:", sponsorResult.paymasterAndData.slice(0, 30) + "...");
    
    // Update UserOp with paymaster data
    userOp.paymasterAndData = sponsorResult.paymasterAndData;
    userOp.callGasLimit = sponsorResult.callGasLimit || userOp.callGasLimit;
    userOp.verificationGasLimit = sponsorResult.verificationGasLimit || userOp.verificationGasLimit;
    userOp.preVerificationGas = sponsorResult.preVerificationGas || userOp.preVerificationGas;
    
    console.log("\n✅ UserOp updated with paymaster data");
    console.log("🔄 Next: Sign and submit to bundler");
    
    return userOp;
  } catch (e) {
    console.error("❌ Sponsorship failed:", e.details || e.message);
  }
}

testBundler().catch(console.error);
