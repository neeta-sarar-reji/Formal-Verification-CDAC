# RVFI notes

RVFI (RISC-V Formal Interface) is a standard set of output signals through which a core
reports every retired instruction. The riscv-formal checkers treat the core as a black box
and judge only this report.

## Role in this project
- PicoRV32 **already implements RVFI**, enabled by the `RISCV_FORMAL` define (set by riscv-formal).
  No RVFI code was written in this project.
- All riscv-formal checks (instruction + consistency) read RVFI.
- `formal/mem_protocol` (own proof) does **not** use RVFI; it checks the memory bus only.
- Inspect the PicoRV32 implementation:
  `grep -n "rvfi_" external/picorv32/picorv32.v` and `external/riscv-formal/docs/rvfi.md`.

## Signal groups
| Group | Signals |
|---|---|
| Control | rvfi_valid, rvfi_order, rvfi_insn, rvfi_trap, rvfi_halt, rvfi_intr, rvfi_mode, rvfi_ixl |
| Registers | rvfi_rs1_addr/rdata, rvfi_rs2_addr/rdata, rvfi_rd_addr/wdata |
| PC | rvfi_pc_rdata, rvfi_pc_wdata |
| Memory | rvfi_mem_addr, rvfi_mem_rmask/rdata, rvfi_mem_wmask/wdata |

## Check families
- `insn_<name>_ch0`: one per instruction; RVFI report must equal the ISA spec model.
- Consistency checks (e.g. `reg`, `pc_fwd`, `pc_bwd`, `causal`, `unique`, `liveness`): reports must
  form one coherent execution. The exact set run is listed in `results/riscv_formal_results.csv`.

## Relevance to the next step
Porting to a 64-bit VEGA core requires writing the RVFI output logic (XLEN=64, 8-bit memory masks,
`rvfi_ixl=2`, W-instruction sign extension) and a wrapper with bus assumptions.
Planned flow: Yosys parse test -> RVFI hookup -> Verilator trace vs Spike -> riscv-formal staged bring-up.
