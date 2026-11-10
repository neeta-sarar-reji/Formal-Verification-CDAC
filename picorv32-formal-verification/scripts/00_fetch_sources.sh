#!/usr/bin/env bash
# Clones PicoRV32 and riscv-formal into external/ (not committed to this repo).
set -e
source "$(dirname "$0")/env.sh"
mkdir -p "$EXT" && cd "$EXT"
[ -d picorv32 ]      || git clone https://github.com/YosysHQ/picorv32.git
[ -d riscv-formal ]  || git clone https://github.com/YosysHQ/riscv-formal.git
echo "picorv32     : $(git -C picorv32 rev-parse HEAD)"
echo "riscv-formal : $(git -C riscv-formal rev-parse HEAD)"
