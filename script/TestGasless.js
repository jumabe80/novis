const { ethers } = require("ethers");

const PIMLICO_URL = "https://api.pimlico.io/v2/base/rpc?apikey=pim_jgoAKhhYAdbSY8KUeUdQBH";
const RPC_URL = "https://mainnet.base.org";
const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
const SMART_ACCOUNT = "0x9503c0681b4f7bFDc8C39cC1954A458009987Cb9";
const NOVIS_TOKEN = "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85";
const OWNER_PK = process.env.PRIVATE_KEY;

async function main() {
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const owner = new ethers.Wallet(OWNER_PK, provider);
    
    console.log("Owner:", owner.address);
    console.log("Smart Account:", SMART_ACCOUNT);
    
    // Get nonce
    const entryPoint = new ethers.Contract(ENTRY_POINT, [
        "function getNonce(address,uint192) view returns (uint256)"
    ], provider);
    const nonce = await entryPoint.getNonce(SMART_ACCOUNT, 0);
    console.log("Nonce:", nonce.toString());
    
    // Build callData - transfer 0.01 NOVIS to owner
    const novisInterface = new ethers.Interface([
        "function transfer(address,uint256) returns (bool)"
    ]);
    const transferData = novisInterface.encodeFunctionData("transfer", [
        owner.address,
        ethers.parseEther("0.01")
    ]);
    
    const accountInterface = new ethers.Interface([
        "function execute(address,uint256,bytes)"
    ]);
    const callData = accountInterface.encodeFunctionData("execute", [
        NOVIS_TOKEN,
        0,
        transferData
    ]);
    
    // Get gas prices from Pimlico
    const pimlicoResponse = await fetch(PIMLICO_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            jsonrpc: "2.0",
            method: "pimlico_getUserOperationGasPrice",
            params: [],
            id: 1
        })
    });
    const gasPrices = (await pimlicoResponse.json()).result.fast;
    
    // Build UserOp
    const userOp = {
        sender: SMART_ACCOUNT,
        nonce: "0x" + nonce.toString(16),
        initCode: "0x",
        callData: callData,
        callGasLimit: "0x50000",
        verificationGasLimit: "0x60000",
        preVerificationGas: "0x10000",
        maxFeePerGas: gasPrices.maxFeePerGas,
        maxPriorityFeePerGas: gasPrices.maxPriorityFeePerGas,
        paymasterAndData: "0x",
        signature: "0x"
    };
    
    // Get paymaster sponsorship
    const sponsorResponse = await fetch(PIMLICO_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            jsonrpc: "2.0",
            method: "pm_sponsorUserOperation",
            params: [userOp, ENTRY_POINT],
            id: 2
        })
    });
    const sponsorResult = (await sponsorResponse.json()).result;
    console.log("Paymaster sponsored:", !!sponsorResult.paymasterAndData);
    
    userOp.paymasterAndData = sponsorResult.paymasterAndData;
    userOp.preVerificationGas = sponsorResult.preVerificationGas;
    userOp.verificationGasLimit = sponsorResult.verificationGasLimit;
    userOp.callGasLimit = sponsorResult.callGasLimit;
    
    // Get UserOp hash and sign
    const userOpHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "uint256", "bytes32", "bytes32", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"],
            [
                userOp.sender,
                userOp.nonce,
                ethers.keccak256(userOp.initCode),
                ethers.keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                ethers.keccak256(userOp.paymasterAndData)
            ]
        )
    );
    
    const chainId = 8453;
    const finalHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes32", "address", "uint256"],
            [userOpHash, ENTRY_POINT, chainId]
        )
    );
    
    const signature = await owner.signMessage(ethers.getBytes(finalHash));
    userOp.signature = signature;
    
    console.log("Submitting UserOp...");
    
    // Submit to bundler
    const submitResponse = await fetch(PIMLICO_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            jsonrpc: "2.0",
            method: "eth_sendUserOperation",
            params: [userOp, ENTRY_POINT],
            id: 3
        })
    });
    const submitResult = await submitResponse.json();
    console.log("Result:", JSON.stringify(submitResult, null, 2));
}

main().catch(console.error);
