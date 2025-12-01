#!/usr/bin/env bash
set -e
TA=$(cast call "$STRAT" "totalAssets()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
APS=$(cast call "$STRAT" "assetsPerShare()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
TS=$(cast call "$STRAT" "totalSupply()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
python3 - "$TA" "$APS" "$TS" <<'PY'
import sys
TA=int(sys.argv[1]); APS=int(sys.argv[2]); TS=int(sys.argv[3])
exp = TS*APS/1e18
delta = TA - exp
pct = (delta/TA*100) if TA else 0.0
print(f"totalAssets={TA:.0f} expected={exp:.0f} delta={delta:.0f} pct={pct:.4f}%")
PY
