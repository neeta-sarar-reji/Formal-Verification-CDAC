#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
{
 echo "date: $(date -u +%F)"
 yosys -V; sby --version; verilator --version; boolector --version
 echo "picorv32:     $(git -C $EXT/picorv32 rev-parse HEAD)"
 echo "riscv-formal: $(git -C $EXT/riscv-formal rev-parse HEAD)"
} 2>&1 | tee "$REPO_ROOT/results/tool_versions.txt"
