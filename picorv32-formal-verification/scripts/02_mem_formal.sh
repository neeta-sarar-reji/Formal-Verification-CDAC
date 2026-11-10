#!/usr/bin/env bash
# Own memory-protocol proof: BMC (depth 30) + cover.
source "$(dirname "$0")/env.sh"
W="$REPO_ROOT/build_mem"; rm -rf "$W"; mkdir -p "$W"
cp "$EXT/picorv32/picorv32.v" "$REPO_ROOT/formal/mem_protocol/"{formal_mem.sv,mem.sby} "$W/"
cd "$W"
sby -f mem.sby bmc   2>&1 | tee "$REPO_ROOT/results/mem_bmc.log"   | tail -5
sby -f mem.sby cover 2>&1 | tee "$REPO_ROOT/results/mem_cover.log" | tail -5
