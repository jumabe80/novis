const { createModularAccountAlchemyClient } = require("@alchemy/aa-alchemy");
const { LocalAccountSigner } = require("@alchemy/aa-core");
const { base } = require("viem/chains");

async function main() {
  let pk = process.env.PRIVATE_KEY;
  if (!pk.startsWith('0x')) pk = '0x' + pk;
  if (pk.length !== 66) throw new Error("Private key must be 64 hex chars (66 with 0x)");
  
  const signer = LocalAccountSigner.privateKeyToAccountSigner(pk);
  
  const client = await createModularAccountAlchemyClient({
    apiKey: process.env.ALCHEMY_API_KEY,
    chain: base,
    signer,
    gasManagerConfig: {
      policyId: process.env.ALCHEMY_GAS_POLICY_ID,
    },
  });

  console.log("Smart Account:", await client.getAddress());
}

main().catch(console.error);
