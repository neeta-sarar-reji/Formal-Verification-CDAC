#!/usr/bin/env bash
# Verilator build + run of the 8-instruction test program on PicoRV32.
source "$(dirname "$0")/env.sh"
W="$REPO_ROOT/build_sim"; rm -rf "$W"; mkdir -p "$W"
cp "$EXT/picorv32/picorv32.v" "$REPO_ROOT/sim/"{sim_main.cpp,prog.hex} "$W/"
cd "$W"
verilator -Wno-fatal --cc --exe --build --trace --top-module picorv32 \
  --Mdir obj_picorv32 picorv32.v sim_main.cpp -o sim_picorv32
./obj_picorv32/sim_picorv32 | tee "$REPO_ROOT/results/sim_output.txt"
echo "exit code: ${PIPESTATUS[0]}"
