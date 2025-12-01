#!/usr/bin/env bash
set -e
cast send "$STRAT" "donate(uint256)" 20000 --account ops --password-file ~/.foundry/pass_ops --rpc-url "$RPC" >/dev/null
./scripts/status.sh
