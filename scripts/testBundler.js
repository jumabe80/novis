const { http, createWalletClient, parseEther, encodeFunctionData } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { base } = require('viem/chains');

const pk = process.env.PRIVATE_KEY.startsWith('0x') ? process.env.PRIVATE_KEY : `0x${process.env.PRIVATE_KEY}`;
const account = privateKeyToAccount(pk);
const SMART_ACCOUNT = "0x29211596dbdaa1af2ca8973cae0f6eae4e75b34f";
const NOVIS = "0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6";
const RECIPIENT = "0x685F3040003E20Bf09488C8B9354913a00627f7a";

const client = createWalletClient({
  account,
  chain: base,
  transport: http(process.env.ALCHEMY_RPC_URL)
});

const transferData = "0xa9059cbb" + encodeFunctionData({
  abi: [{ name: 'transfer', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ type: 'bool' }] }],
  functionName: 'transfer',
  args: [RECIPIENT, parseEther('2')]
}).slice(2);

client.sendTransaction({
  to: SMART_ACCOUNT,
  data: encodeFunctionData({
    abi: [{ name: 'execute', type: 'function', inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }] }],
    functionName: 'execute',
    args: [NOVIS, 0n, transferData]
  }),
  gas: 300000n
}).then(hash => console.log("Tx:", hash)).catch(e => console.error(e.message));
