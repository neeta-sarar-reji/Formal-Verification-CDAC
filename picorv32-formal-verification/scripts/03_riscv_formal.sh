#!/usr/bin/env bash
# Generates and runs all riscv-formal checks for PicoRV32. Takes a long time.
# Usage: scripts/03_riscv_formal.sh [jobs]
source "$(dirname "$0")/env.sh"
J="${1:-4}"
cd "$EXT/riscv-formal/cores/picorv32"
cp checks.cfg "$REPO_ROOT/results/checks.cfg.used"      # record exact configuration
python3 ../../checks/genchecks.py
make -C checks -j"$J" 2>&1 | tee "$REPO_ROOT/results/riscv_formal_run.log" | tail -5
