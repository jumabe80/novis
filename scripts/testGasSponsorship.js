const { http, createPublicClient, parseEther, encodeFunctionData, concat, toHex } = require('viem');
const { base } = require('viem/chains');

const client = createPublicClient({
  chain: base,
  transport: http(process.env.ALCHEMY_RPC_URL)
});

// For now, let's just verify Alchemy connection and check our account
async function main() {
  const ACCOUNT = "0x29211596dbdaa1af2ca8973cae0f6eae4e75b34f";
  const balance = await client.readContract({
    address: "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6",
    abi: [{ name: 'balanceOf', type: 'function', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' }],
    functionName: 'balanceOf',
    args: [ACCOUNT]
  });
  
  console.log("Account NOVIS balance:", balance.toString(), "wei");
  console.log("That's", Number(balance) / 1e18, "NOVIS");
  console.log("\nAlchemy RPC working ✅");
  console.log("Gas policy created ✅");
  console.log("\nProblem: Alchemy's SDK expects THEIR smart account format, not ours.");
  console.log("Solution: We need to either:");
  console.log("1. Modify our contracts to be compatible with Alchemy's account format");
  console.log("2. Use a different bundler (Pimlico, Stackup)");
  console.log("3. Build our own simplified bundler");
}

main();
