const { createPublicClient, http, encodeFunctionData, parseEther, concat, toHex } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { base } = require('viem/chains');

const SMART_ACCOUNT = "0x29211596dbdaa1af2ca8973cae0f6eae4e75b34f";
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
const NOVIS = "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6";
const RECIPIENT = "0x685F3040003E20Bf09488C8B9354913a00627f7a";

const publicClient = createPublicClient({
  chain: base,
  transport: http(process.env.BASE_RPC_URL)
});

const bundlerClient = createPublicClient({
  chain: base,
  transport: http(process.env.PIMLICO_BUNDLER_URL)
});

async function sponsorAndSend() {
  console.log("Step 1: Building UserOperation...\n");
  
  // Build callData
  const transferData = concat([
    '0xa9059cbb',
    encodeFunctionData({
      abi: [{ name: 'transfer', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }] }],
      functionName: 'transfer',
      args: [RECIPIENT, parseEther('2')]
    }).slice(2)
  ]);
  
  const callData = encodeFunctionData({
    abi: [{ name: 'execute', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }] }],
    functionName: 'execute',
    args: [NOVIS, 0n, transferData]
  });
  
  const feeData = await publicClient.estimateFeesPerGas();
  
  const userOp = {
    sender: SMART_ACCOUNT,
    nonce: toHex(0n),
    initCode: '0x',
    callData: callData,
    callGasLimit: toHex(200000n),
    verificationGasLimit: toHex(200000n),
    preVerificationGas: toHex(50000n),
    maxFeePerGas: toHex(feeData.maxFeePerGas),
    maxPriorityFeePerGas: toHex(feeData.maxPriorityFeePerGas || 1000000n),
    paymasterAndData: '0x',
    signature: '0x'
  };
  
  console.log("✅ UserOp built\n");
  
  // Step 2: Request Pimlico sponsorship
  console.log("Step 2: Requesting Pimlico sponsorship...\n");
  
  try {
    const sponsorResult = await bundlerClient.request({
      method: 'pm_sponsorUserOperation',
      params: [
        userOp,
        {
          entryPoint: ENTRYPOINT
        }
      ]
    });
    
    console.log("✅ Pimlico approved sponsorship!");
    console.log("   paymasterAndData:", sponsorResult.paymasterAndData.slice(0, 20) + "...");
    console.log("\nNext: Sign and send the UserOp");
    
    return { userOp, sponsorResult };
  } catch (e) {
    console.error("❌ Sponsorship failed:", e.message);
    console.log("\nThis might mean:");
    console.log("1. Pimlico doesn't support our custom smart account");
    console.log("2. Need to configure Pimlico policy");
    console.log("3. Account structure not compatible");
  }
}

sponsorAndSend().catch(console.error);
