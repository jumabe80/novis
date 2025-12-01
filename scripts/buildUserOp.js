const { createPublicClient, http, encodeFunctionData, parseEther, concat, toHex } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { base } = require('viem/chains');

const SMART_ACCOUNT = "0x29211596dbdaa1af2ca8973cae0f6eae4e75b34f";
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
const NOVIS = "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6";
const RECIPIENT = "0x685F3040003E20Bf09488C8B9354913a00627f7a";

const account = privateKeyToAccount(process.env.PRIVATE_KEY);

const publicClient = createPublicClient({
  chain: base,
  transport: http(process.env.BASE_RPC_URL)
});

async function buildUserOp() {
  console.log("Building UserOperation...\n");
  
  // 1. Build callData
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
  
  console.log("✅ callData built");
  
  // 2. Nonce (start with 0 - first ERC-4337 transaction)
  const nonce = 0n;
  console.log("✅ nonce:", nonce.toString());
  
  // 3. Gas prices
  const feeData = await publicClient.estimateFeesPerGas();
  console.log("✅ Gas prices fetched");
  
  // 4. Build UserOp
  const userOp = {
    sender: SMART_ACCOUNT,
    nonce: toHex(nonce),
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
  
  console.log("\n📦 UserOp ready!");
  console.log("Next: Request paymaster sponsorship from Pimlico\n");
  
  return userOp;
}

buildUserOp().then(userOp => {
  console.log("UserOp structure:");
  console.log(JSON.stringify(userOp, null, 2));
}).catch(console.error);
