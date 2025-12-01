#!/usr/bin/env bash
set -euo pipefail
NET="${1:-sepolia}"
if [ "$NET" = "sepolia" ]; then
  RPC="https://sepolia.base.org"
  POLICY=0x194f5cC65B1b446059f1630cac7D1Aa66bcccC80
  VAULT=0xA88c2a827ddA537C3C8a0b539CB8691F2c18388E
  EUSD=0x4eD0De6B3d04b045c644285F5878a4E0cC47F062
  USDC=0x4878fF54F1F87162500B5D7091075e441018fF6c
  STRAT=0x9Deac345b3dd58B8E520A55f8485Fe70E45CEFD1
else
  echo "Usage: $0 sepolia"
  exit 2
fi
echo "=== POLICY ==="
printf "owner      : "; cast call $POLICY "owner()(address)" --rpc-url $RPC
printf "guardian   : "; cast call $POLICY "guardian()(address)" --rpc-url $RPC
printf "vault()    : "; cast call $POLICY "vault()(address)" --rpc-url $RPC
printf "eusd()     : "; cast call $POLICY "eusd()(address)" --rpc-url $RPC
printf "usdc()     : "; cast call $POLICY "usdc()(address)" --rpc-url $RPC
printf "strategy() : "; cast call $POLICY "strategy()(address)" --rpc-url $RPC
printf "targetBps  : "; cast call $POLICY "targetBps()(uint256)" --rpc-url $RPC
echo "=== VAULT ==="
printf "owner      : "; cast call $VAULT "owner()(address)" --rpc-url $RPC
printf "eusd()     : "; cast call $VAULT "eusd()(address)" --rpc-url $RPC
printf "usdc()     : "; cast call $VAULT "usdc()(address)" --rpc-url $RPC
printf "strategy() : "; cast call $VAULT "strategy()(address)" --rpc-url $RPC
printf "vaultUSDC  : "; cast call $USDC "balanceOf(address)(uint256)" $VAULT --rpc-url $RPC
echo "=== EUSD ==="
printf "owner      : "; cast call $EUSD "owner()(address)" --rpc-url $RPC
echo "=== STRATEGY ==="
printf "totalAssets: "; cast call $STRAT "totalAssets()(uint256)" --rpc-url $RPC
printf "pps        : "; cast call $STRAT "assetsPerShare()(uint256)" --rpc-url $RPC
