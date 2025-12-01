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
  transport: http(process.env.BASE_RPC_URL || 'https://mainnet.base.org')
});

const bundlerClient = createPublicClient({
  chain: base,
  transport: http(process.env.PIMLICO_BUNDLER_URL)
});

async function submitUserOp() {
  console.log("🚀 Building, signing, and submitting UserOp...\n");
  
  // Build transfer calldata
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
  
  // Get Pimlico's recommended gas price
  console.log("🔄 Getting Pimlico gas price...");
  const gasPrice = await bundlerClient.request({
    method: 'pimlico_getUserOperationGasPrice',
    params: []
  });
  console.log("✅ Gas price:", gasPrice.fast.maxFeePerGas);
  
  // Initial UserOp with Pimlico's gas price
  let userOp = {
    sender: ACCOUNT_V6,
    nonce: toHex(0n),
    initCode: '0x',
    callData: callData,
    callGasLimit: toHex(300000n),
    verificationGasLimit: toHex(300000n),
    preVerificationGas: toHex(100000n),
    maxFeePerGas: gasPrice.fast.maxFeePerGas,
    maxPriorityFeePerGas: gasPrice.fast.maxPriorityFeePerGas,
    paymasterAndData: '0x',
    signature: '0x'
  };
  
  console.log("✅ UserOp built");
  
  // Step 1: Get sponsorship
  console.log("🔄 Requesting sponsorship...");
  const sponsorResult = await bundlerClient.request({
    method: 'pm_sponsorUserOperation',
    params: [userOp, { entryPoint: ENTRYPOINT }]
  });
  
  userOp.paymasterAndData = sponsorResult.paymasterAndData;
  userOp.callGasLimit = sponsorResult.callGasLimit || userOp.callGasLimit;
  userOp.verificationGasLimit = sponsorResult.verificationGasLimit || userOp.verificationGasLimit;
  userOp.preVerificationGas = sponsorResult.preVerificationGas || userOp.preVerificationGas;
  
  console.log("✅ Sponsorship approved!");
  
  // Step 2: Get UserOpHash from EntryPoint
  console.log("🔄 Getting UserOp hash...");
  const userOpHash = await publicClient.readContract({
    address: ENTRYPOINT,
    abi: [{
      name: 'getUserOpHash',
      type: 'function',
      inputs: [{
        name: 'userOp',
        type: 'tuple',
        components: [
          { name: 'sender', type: 'address' },
          { name: 'nonce', type: 'uint256' },
          { name: 'initCode', type: 'bytes' },
          { name: 'callData', type: 'bytes' },
          { name: 'callGasLimit', type: 'uint256' },
          { name: 'verificationGasLimit', type: 'uint256' },
          { name: 'preVerificationGas', type: 'uint256' },
          { name: 'maxFeePerGas', type: 'uint256' },
          { name: 'maxPriorityFeePerGas', type: 'uint256' },
          { name: 'paymasterAndData', type: 'bytes' },
          { name: 'signature', type: 'bytes' }
        ]
      }],
      outputs: [{ type: 'bytes32' }],
      stateMutability: 'view'
    }],
    functionName: 'getUserOpHash',
    args: [{
      sender: ACCOUNT_V6,
      nonce: BigInt(userOp.nonce),
      initCode: userOp.initCode,
      callData: userOp.callData,
      callGasLimit: BigInt(userOp.callGasLimit),
      verificationGasLimit: BigInt(userOp.verificationGasLimit),
      preVerificationGas: BigInt(userOp.preVerificationGas),
      maxFeePerGas: BigInt(userOp.maxFeePerGas),
      maxPriorityFeePerGas: BigInt(userOp.maxPriorityFeePerGas),
      paymasterAndData: userOp.paymasterAndData,
      signature: '0x'
    }]
  });
  
  console.log("✅ UserOp hash:", userOpHash);
  
  // Step 3: Sign the hash
  console.log("🔄 Signing UserOp...");
  const signature = await account.signMessage({
    message: { raw: userOpHash }
  });
  userOp.signature = signature;
  console.log("✅ Signed!");
  
  // Step 4: Submit to bundler
  console.log("🔄 Submitting to bundler...");
  const txHash = await bundlerClient.request({
    method: 'eth_sendUserOperation',
    params: [userOp, ENTRYPOINT]
  });
  
  console.log("\n🎉 SUCCESS! UserOp submitted!");
  console.log("   UserOp Hash:", txHash);
  console.log("\n⏳ Waiting for confirmation...");
  
  // Step 5: Wait for receipt
  let receipt = null;
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 2000));
    try {
      receipt = await bundlerClient.request({
        method: 'eth_getUserOperationReceipt',
        params: [txHash]
      });
      if (receipt) break;
    } catch (e) {}
    process.stdout.write('.');
  }
  
  if (receipt) {
    console.log("\n\n✅ TRANSACTION CONFIRMED!");
    console.log("   Tx Hash:", receipt.receipt.transactionHash);
    console.log("   Block:", parseInt(receipt.receipt.blockNumber, 16));
    console.log("   Success:", receipt.success);
    console.log("\n🔗 View on BaseScan:");
    console.log("   https://basescan.org/tx/" + receipt.receipt.transactionHash);
  } else {
    console.log("\n\n⏳ Still pending. Check manually with UserOp hash:", txHash);
  }
}

submitUserOp().catch(console.error);
