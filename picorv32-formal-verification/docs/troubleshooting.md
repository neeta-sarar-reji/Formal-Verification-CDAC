# Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `command not found` (sby, yosys) | Environment not sourced in this terminal | `source scripts/env.sh` |
| Old tool versions appear | System tools earlier in PATH | Source the environment; confirm with `which` |
| `FileNotFoundError: 'mem.sby'` | File missing from current directory | Run scripts/02_mem_formal.sh or `cd formal/mem_protocol` copy |
| SBY: results folder exists | Old run | Use `sby -f` or delete the folder |
| `FAIL, rc=2` | Assertion violated, or assumption too loose | Open `engine_0/trace.vcd` in GTKWave |
| `rc=16` | Parse/hierarchy error in script | Read the `design.log` in the job folder |
| Verilator: g++/make missing | No compiler | `sudo apt install build-essential` |
| Verilator `--timing` error | Verilator 5 timing check | Add `--no-timing` |
| Terminal stuck after gtkwave | GUI in foreground | Close window, Ctrl+C, or use `&` |
| Laptop sluggish during riscv-formal | Too many parallel jobs | `scripts/03_riscv_formal.sh 2` |
| Stuck solver | Long check | `pkill -f yosys-smtbmc` |

When a check fails, decide in order: (1) RVFI hookup mistake, (2) missing wrapper assumption, (3) real core bug.
