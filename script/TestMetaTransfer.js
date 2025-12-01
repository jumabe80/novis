const { ethers } = require("ethers");

const RPC_URL = "https://mainnet.base.org";
const NOVIS = "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85";
const OWNER_PK = process.env.PRIVATE_KEY;

async function main() {
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const signer = new ethers.Wallet(OWNER_PK, provider);
    
    console.log("Signer:", signer.address);
    
    const novis = new ethers.Contract(NOVIS, [
        "function getMetaTxNonce(address) view returns (uint256)",
        "function metaTransfer(address,address,uint256,uint256,bytes) returns (bool)",
        "function eip712Domain() view returns (bytes1,string,string,uint256,address,bytes32,uint256[])"
    ], signer);
    
    const domain = await novis.eip712Domain();
    const nonce = await novis.getMetaTxNonce(signer.address);
    
    const from = signer.address;
    const to = "0x9503c0681b4f7bFDc8C39cC1954A458009987Cb9";
    const amount = ethers.parseEther("0.5");
    const deadline = Math.floor(Date.now() / 1000) + 3600;
    
    // Use exact domain from contract (empty name/version)
    const domainData = {
        name: domain[1],
        version: domain[2],
        chainId: domain[3],
        verifyingContract: domain[4]
    };
    
    const types = {
        MetaTransfer: [
            { name: "from", type: "address" },
            { name: "to", type: "address" },
            { name: "amount", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" }
        ]
    };
    
    const message = { from, to, amount, nonce, deadline };
    
    // Sign with typed data
    const signature = await signer.signTypedData(domainData, types, message);
    console.log("Signature:", signature);
    
    // Submit
    console.log("Submitting...");
    const tx = await novis.metaTransfer(from, to, amount, deadline, signature, { gasLimit: 200000 });
    console.log("Tx hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("Success! Block:", receipt.blockNumber);
}

main().catch(console.error);
