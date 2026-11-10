#!/usr/bin/env bash
# Verilator lint of picorv32.v (warnings expected, errors not).
source "$(dirname "$0")/env.sh"
cd "$EXT/picorv32"
verilator --lint-only -Wall -Wno-fatal --top-module picorv32 picorv32.v 2>&1 | tee "$REPO_ROOT/results/lint.log"
echo "Errors: $(grep -c '%Error' "$REPO_ROOT/results/lint.log")"
