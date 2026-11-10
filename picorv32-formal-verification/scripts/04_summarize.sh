#!/usr/bin/env bash
# Builds results/riscv_formal_results.csv and prints totals from the checks/ folder.
source "$(dirname "$0")/env.sh"
cd "$EXT/riscv-formal/cores/picorv32/checks" || exit 1
OUT="$REPO_ROOT/results/riscv_formal_results.csv"
echo "check,category,result,elapsed" > "$OUT"
for d in */; do n=${d%/}
  case $n in insn_*) c=instruction;; *) c=consistency;; esac
  r=$( [ -f $d/PASS ] && echo PASS || ([ -f $d/FAIL ] && echo FAIL || echo UNKNOWN) )
  t=$(grep -m1 "Elapsed clock time" $d/logfile.txt 2>/dev/null | sed 's/.*: //')
  echo "$n,$c,$r,\"$t\"" >> "$OUT"
done
{ head -1 "$OUT"; tail -n +2 "$OUT" | sort; } > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
echo "Total jobs : $(ls -d */ | wc -l)"
echo "PASS       : $(ls */PASS 2>/dev/null | wc -l)"
echo "FAIL       : $(ls */FAIL 2>/dev/null | wc -l)"
echo "Instruction: $(ls -d insn_*/ 2>/dev/null | wc -l)"
echo "Consistency: $(ls -d */ | grep -vc '^insn_')"
echo "Wrote $OUT"
