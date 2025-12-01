const { http, createPublicClient } = require('viem');
const { base } = require('viem/chains');

const bundlerClient = createPublicClient({
  chain: base,
  transport: http(process.env.PIMLICO_BUNDLER_URL)
});

async function main() {
  // Test bundler connection
  const chainId = await bundlerClient.request({ method: 'eth_chainId' });
  console.log("Pimlico bundler connected ✅");
  console.log("Chain ID:", parseInt(chainId, 16));
  
  // Check if bundler supports our EntryPoint
  const entryPoint = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
  console.log("EntryPoint:", entryPoint);
  console.log("\nNext: Create UserOperation with our smart account");
}

main().catch(console.error);
