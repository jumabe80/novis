#!/usr/bin/env bash
set -e
echo -n "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) "
echo -n "vaultUSDC="; cast call "$VAULT2" "vaultUSDC()(uint256)" --rpc-url "$RPC"
echo -n " strat.totalAssets="; cast call "$STRAT" "totalAssets()(uint256)" --rpc-url "$RPC"
echo -n " strat.assetsPerShare="; cast call "$STRAT" "assetsPerShare()(uint256)" --rpc-url "$RPC"
echo -n " policy.targetUsdc="; cast call "$POLICY" "targetUsdc()(uint256)" --rpc-url "$RPC"
echo -n " policy.deviationUsdc="; cast call "$POLICY" "deviationUsdc()(int256)" --rpc-url "$RPC"
