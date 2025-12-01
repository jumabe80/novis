const { http, createPublicClient, createWalletClient, encodeFunctionData, parseEther, concat } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { base } = require('viem/chains');

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const SMART_ACCOUNT = "0x29211596dbdaa1af2ca8973cae0f6eae4e75b34f";
const NOVIS = "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6";
const RECIPIENT = "0x685F3040003E20Bf09488C8B9354913a00627f7a";
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

const bundlerClient = createPublicClient({
  chain: base,
  transport: http(process.env.PIMLICO_BUNDLER_URL)
});

async function main() {
  // Encode NOVIS transfer (2 NOVIS - under $10, should be sponsored)
  const transferCalldata = concat([
    '0xa9059cbb',
    encodeFunctionData({
      abi: [{ name: 'transfer', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }] }],
      functionName: 'transfer',
      args: [RECIPIENT, parseEther('2')]
    }).slice(2)
  ]);
  
  // Encode execute call on smart account
  const executeCalldata = encodeFunctionData({
    abi: [{ name: 'execute', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }] }],
    functionName: 'execute',
    args: [NOVIS, 0n, transferCalldata]
  });
  
  console.log("Calldata prepared ✅");
  console.log("Next: Build UserOperation and submit to bundler");
  console.log("\nThis requires:");
  console.log("1. Get nonce from EntryPoint");
  console.log("2. Estimate gas");
  console.log("3. Sign UserOperation");
  console.log("4. Submit to Pimlico");
  
  // Get nonce
  const publicClient = createPublicClient({ chain: base, transport: http(process.env.ALCHEMY_RPC_URL) });
  const nonce = await publicClient.readContract({
    address: ENTRYPOINT,
    abi: [{ name: 'getNonce', type: 'function', inputs: [{ type: 'address' }, { type: 'uint192' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' }],
    functionName: 'getNonce',
    args: [SMART_ACCOUNT, 0n]
  });
  
  console.log("\nNonce:", nonce.toString());
}

main().catch(console.error);
