# Formal Verification of the PicoRV32 RISC-V Core
### SymbiYosys + riscv-formal (RVFI) + Verilator, using the OSS CAD Suite

| | |
|---|---|
| **Author** | [FILL name] |
| **Project lead** | [FILL] |
| **Date** | [FILL] |
| **Design under test** | PicoRV32 (32-bit RISC-V CPU), https://github.com/YosysHQ/picorv32 |
| **Purpose** | Learn and demonstrate the formal verification flow; groundwork for formal verification and RVFI integration of the 64-bit VEGA core (C-DAC) |

---

## Table of contents
1. [Summary of results](#1-summary-of-results)
2. [Repository layout](#2-repository-layout)
3. [Theory: verification basics](#3-theory-verification-basics)
4. [Tools and what each does](#4-tools-and-what-each-does)
5. [Step 0: Checking the original environment](#5-step-0-checking-the-original-environment)
6. [Step 1: Activating the OSS CAD Suite](#6-step-1-activating-the-oss-cad-suite)
7. [Step 2: Getting PicoRV32 and linting it](#7-step-2-getting-picorv32-and-linting-it)
8. [Step 3: riscv-formal ISA proof (RVFI)](#8-step-3-riscv-formal-isa-proof-rvfi)
9. [Step 4: Own memory-protocol proof (bmc + cover)](#9-step-4-own-memory-protocol-proof-bmc--cover)
10. [Step 5: Simulation with Verilator](#10-step-5-simulation-with-verilator)
11. [RVFI in detail](#11-rvfi-in-detail)
12. [Formal inputs, assumptions and data types](#12-formal-inputs-assumptions-and-data-types)
13. [Role of Verilator in a formal flow](#13-role-of-verilator-in-a-formal-flow)
14. [How to reproduce everything](#14-how-to-reproduce-everything)
15. [Limitations and honest notes](#15-limitations-and-honest-notes)
16. [Next steps: 64-bit VEGA core](#16-next-steps-64-bit-vega-core)
17. [Glossary](#17-glossary)
18. [Troubleshooting](#18-troubleshooting)
19. [References and licence](#19-references-and-licence)

---

## 1. Summary of results

| # | Activity | Tool | Result |
|---|---|---|---|
| 1 | Verilator lint of `picorv32.v` | Verilator 5.053 | No errors; style warnings only |
| 2 | riscv-formal ISA proof (uses RVFI) | SBY + Boolector | **87 of 87 jobs PASS**; 0 FAIL; no timeouts or errors |
| 3 | Own memory-protocol proof, BMC depth 30 | SBY + Boolector | **PASS** (steps 0 to 29, no violation) |
| 4 | Own cover check (non-vacuity) | SBY + Boolector | **PASS** (instruction fetch reached at step 4) |
| 5 | Simulation of a hand-assembled program | Verilator + C++ testbench | **PASS**, exit code 0 |

Important qualifiers:
- All formal runs are **bounded model checking (BMC)**: no violation exists within the checked depth. The riscv-formal instruction checks were observed running to step 20; the memory proof uses depth 30. These are not unbounded proofs.
- RVFI was **used** (PicoRV32 ships its own RVFI output logic) but **not written** in this project. Only the riscv-formal checks use RVFI; the own memory proof does not.
- Checked configuration (ISA string, depths): see `results/checks.cfg.used` after running script 03. [FILL: paste the `isa` line here]
- Breakdown of the 87 jobs into instruction and consistency checks: see `results/riscv_formal_results.csv` (script 04). [FILL counts]

---

## 2. Repository layout

```
.
├── README.md                      this document
├── .gitignore
├── formal/mem_protocol/
│   ├── formal_mem.sv              wrapper + assumptions + assertions + cover
│   └── mem.sby                    SBY job file (tasks: bmc, cover)
├── sim/
│   ├── prog.hex                   hand-assembled 8-instruction test program
│   └── sim_main.cpp               Verilator C++ testbench (memory model)
├── scripts/
│   ├── env.sh                     activates OSS CAD Suite, sets paths
│   ├── 00_fetch_sources.sh        clones PicoRV32 and riscv-formal into external/
│   ├── 01_lint.sh                 Verilator lint
│   ├── 02_mem_formal.sh           own proof: bmc + cover
│   ├── 03_riscv_formal.sh         generate and run all riscv-formal checks
│   ├── 04_summarize.sh            results CSV and totals
│   ├── 05_simulate.sh             Verilator build and run
│   └── record_versions.sh         tool versions and commit hashes
├── results/                       logs, CSV, configuration used (generated)
└── docs/
    ├── rvfi_notes.md              RVFI quick reference
    ├── GITLAB_UPLOAD.md           how to publish this repo
    └── troubleshooting.md         error cheat sheet
```

PicoRV32 and riscv-formal are third-party projects and are **not copied** into this repository. `scripts/00_fetch_sources.sh` clones them into `external/` (git-ignored), and `results/tool_versions.txt` records the exact commits used.

---

## 3. Theory: verification basics

### 3.1 Why verify a CPU
A hardware bug cannot be patched after fabrication, and even on an FPGA a CPU bug is hard to locate. A design is therefore checked with several complementary techniques.

| Technique | What it does | Strength | Weakness |
|---|---|---|---|
| Lint | Static scan of the code for suspicious constructs | Instant; catches careless mistakes | Does not check behaviour |
| Simulation | Runs chosen programs and watches signals | Fast; can run millions of cycles | Tests only what you think of |
| Formal verification | A solver searches all input sequences up to a depth for a rule violation | Exhaustive within its depth | Reaches only a limited number of cycles |

All three were used here because each covers the others' weaknesses.

### 3.2 Formal verification concepts
- **Assertion**: a rule that must always hold (`assert(cond)`).
- **Assumption**: a restriction on what the environment's inputs may do (`assume(cond)`). Too few assumptions give false failures; too many hide real bugs.
- **Cover**: a check that a scenario is reachable (`cover(cond)`). It guards against **vacuous proofs**, where an assertion passes only because the situation it guards never occurs.
- **Bounded model checking (BMC)**: the design is unrolled for N clock cycles and an SMT solver searches every allowed input sequence for an assertion violation. A pass means "no violation within N cycles", not "never".
- **Unbounded proof** (`mode prove`, k-induction or PDR): proves the rule for all time, but may need extra invariants. Not performed here.
- **Counterexample (trace)**: if a rule can be broken the solver returns the exact input sequence, saved as a `.vcd` waveform.
- **Solver**: the SMT engine (Boolector, Z3, Yices) that does the mathematical search. Boolector was used.

### 3.3 Bounded versus unbounded, in this project
Every formal result here is bounded. For riscv-formal this is the standard and accepted practice for PicoRV32: the checks examine each retired instruction in isolation and consistency checks link them together, so the bounded depth covers reset, fetch, execute and retire of an instruction.

---

## 4. Tools and what each does

| Tool | Role |
|---|---|
| Yosys | Reads Verilog/SystemVerilog and converts it to a solver-friendly form |
| SBY (SymbiYosys) | Formal front-end: reads a `.sby` job file, runs Yosys, calls the solver |
| Boolector, Z3, Yices | SMT solvers (Boolector used) |
| Verilator | Linter and fast C++ simulator; proves nothing |
| Icarus Verilog | Alternative simulator (installed, not used) |
| GTKWave | Waveform viewer for `.vcd` files |
| OSS CAD Suite | Bundle of up-to-date versions of all of the above |

Versions used: Yosys 0.69+208, SBY v0.69, Verilator 5.053 (full record in `results/tool_versions.txt`).

---

## 5. Step 0: Checking the original environment

```bash
verilator --version
yosys -V
sby --version
boolector --version
z3 --version
iverilog -V
```
**Aim:** discover which tools exist and how old they are.
**Found:** apt-installed Verilator 4.038 and Yosys 0.9 (both old), `sby` and `z3` missing, Boolector 1.5.118 and Icarus 11.0 present.
**Conclusion:** the apt toolchain was unsuitable (no SBY, outdated Yosys). The OSS CAD Suite, which bundles Yosys 0.69 and SBY, was used instead.

---

## 6. Step 1: Activating the OSS CAD Suite

```bash
source ~/Downloads/oss-cad-suite/environment
which yosys sby verilator boolector z3 yices-smt2
```
**Theory:** `source` runs the suite's `environment` script in the current shell. It places the suite's `bin` directory first in `PATH` (the list of directories searched for programs), so its tools override the old system ones. The effect lasts only for that terminal, so **every new terminal needs this command again**.
**Expected:** every path begins with `.../oss-cad-suite/bin/` and the prompt shows `⦗OSS CAD Suite⦘`.
**Observed:** all six tools resolved into the suite, including `z3`, which was previously missing.
**Script:** `scripts/env.sh`.

---

## 7. Step 2: Getting PicoRV32 and linting it

```bash
mkdir -p ~/formal && cd ~/formal
git clone https://github.com/YosysHQ/picorv32.git
cd picorv32
verilator --lint-only -Wall -Wno-fatal --top-module picorv32 picorv32.v
```
**Theory:** PicoRV32 is a size-optimised RISC-V CPU written in Verilog, contained in the single file `picorv32.v`. Linting parses the code and applies static rules without running it, like a spell-check for hardware. Flags: `--lint-only` (no build), `-Wall` (all warning classes), `-Wno-fatal` (warnings do not abort), `--top-module` (main module).
**Expected:** no errors; warnings are normal for this design.
**Observed:** no errors. Warnings were `DECLFILENAME` (module name differs from file name), `GENUNNAMED` (unnamed generate blocks), `BLKSEQ` (blocking assignments in clocked logic, a deliberate style choice by the author) and `UNUSEDSIGNAL` (debug signals `dbg_*`).
**Script:** `scripts/01_lint.sh`.

---

## 8. Step 3: riscv-formal ISA proof (RVFI)

```bash
git clone https://github.com/YosysHQ/riscv-formal.git
cd riscv-formal/cores/picorv32
python3 ../../checks/genchecks.py
make -C checks -j$(nproc)
```

### 8.1 Theory
- **RISC-V** is an open specification defining exactly what every instruction does.
- **RVFI** is a standard set of output signals through which a core reports each retired instruction (section 11).
- **riscv-formal** is a framework of SystemVerilog checkers that observe RVFI and compare it with a formal model of the specification. The core is treated as a black box.
- **`checks.cfg`** (in `cores/picorv32/`) selects the ISA, depths per check type and source files. **`genchecks.py`** reads it and writes one `.sby` job per check into `checks/`. `make -C checks -j<N>` runs all jobs in parallel (`-C` changes into `checks/`).

### 8.2 Instruction checks (`insn_<name>_ch0`)
One job per instruction in the configured ISA (`_ch0` = RVFI channel 0). For each job:
1. The solver freely chooses the instruction stream (through the free memory-read data), operand values and memory contents.
2. The checker assumes that the retired instruction is the one under test (`spec_valid`).
3. A spec model (`riscv-formal/insns/insn_<name>.v`) decodes `rvfi_insn` and computes the expected outputs.
4. Assertions require the RVFI report to equal the model: trap flag, source and destination register numbers, `rd_wdata`, `pc_wdata`, and memory address, masks and data.

| Class | Instructions (RV32I) | Spec checks |
|---|---|---|
| Register-register ALU | add, sub, sll, slt, sltu, xor, srl, sra, or, and | `rd = f(rs1, rs2)`; next PC = pc+4; no memory access |
| Register-immediate ALU | addi, slti, sltiu, xori, ori, andi, slli, srli, srai | immediate sign extension; shift amounts |
| Upper immediate | lui, auipc | `rd = imm` or `pc + imm` |
| Branches | beq, bne, blt, bge, bltu, bgeu | taken: next PC = pc + imm, else pc + 4; misaligned target traps |
| Jumps | jal, jalr | `rd = pc + 4`; target (jalr clears bit 0) |
| Loads | lb, lh, lw, lbu, lhu | address, read mask, sign/zero extension, alignment trap |
| Stores | sb, sh, sw | address, write mask, data in correct byte lanes |

This table is the standard RV32I set (37 instructions). The exact set run in this project depends on `isa` in `checks.cfg` and is listed in `results/riscv_formal_results.csv`. Passing instruction checks seen in the pasted logs included sub, xor, xori, sra, srai, srl, srli, sb, sh, sw and lhu.

### 8.3 Consistency checks
An instruction check trusts the operands the core reports. A core could report operands that came from nowhere and still pass every instruction check. Consistency checks close this gap by verifying that the stream of reports forms one believable execution. They are instruction-agnostic: the solver picks any instruction stream.

| Check | Idea | Aim |
|---|---|---|
| `reg` | Reported `rs1/rs2` values equal the value last written to that register (matched with `rvfi_order`) | Operands are real; register file and forwarding are honest |
| `pc_fwd` | Next instruction's `pc_rdata` equals this one's `pc_wdata` | Control flow has no unexplained jumps |
| `pc_bwd` | The same link checked from the later instruction | Catches mismatches `pc_fwd` could miss |
| `causal` | An instruction's report does not depend on later instructions | No dependence on the future |
| `unique` | Each `rvfi_order` value retires at most once | No duplicate retirements |
| `liveness` | A fetched instruction with responding memory retires within a bound | The core does not hang |
| `ill`, `csr*`, `bus*`, `cover` | Illegal-instruction, CSR, bus and reachability checks | Present only if enabled in `checks.cfg` |

Only `reg_ch0` was individually confirmed in the saved logs (about 12 minutes). Which of the other consistency jobs exist in this run is recorded by script 04 in `results/riscv_formal_results.csv`.

Together the families form a chain: each instruction is correct given its inputs (`insn`), the inputs are the results of earlier instructions (`reg`, `pc_*`), and the ordering is sane (`causal`, `unique`).

### 8.4 Expected and observed
**Expected:** each job ends `DONE (PASS, rc=0)`.
**Observed from logs:** `Checking assertions in step 20..`; typical run times: shifts and logic 1 to 2 minutes, loads and stores 2 to 6 minutes, `reg_ch0` about 12 minutes. `engine_0 did not produce any traces` is good news: traces are only written for counterexamples or cover hits.

### 8.5 Verifying the whole run (not just the log tail)
```bash
cd ~/riscv-formal/cores/picorv32
ls checks/*/PASS | wc -l                         # passing jobs
ls checks/*/FAIL 2>/dev/null                     # should print nothing
ls -d checks/*/ | wc -l                          # total jobs
grep -L "DONE (PASS" checks/*/logfile.txt        # logs without a PASS line
grep -l "TIMEOUT\|ERROR" checks/*/logfile.txt    # timeouts or errors
```
Each job writes a `PASS` or `FAIL` marker file in its folder. `grep -L` lists files **not** containing the text; `grep -l` lists files that do.
**Observed:** `87`, nothing, `87`, nothing, nothing. All 87 jobs passed.

### 8.6 Meaning
For this configuration, no instruction violated the RISC-V specification within the checked depth, as reported through RVFI, for all operand values and all surrounding instruction streams the wrapper allows.

**Scripts:** `scripts/00_fetch_sources.sh`, `scripts/03_riscv_formal.sh`, `scripts/04_summarize.sh`.

---

## 9. Step 4: Own memory-protocol proof (bmc + cover)

This step shows how to write a formal property from scratch. **It does not use RVFI.**

### 9.1 Files
Showing file contents does not create them; the files are created with the `cat > file << 'EOF'` pattern, or are simply the files in `formal/mem_protocol/`.

**`formal_mem.sv`** (wrapper):
- `(* anyseq *)` on `resetn`, `mem_ready`, `mem_rdata`: the solver may change these arbitrarily every cycle.
- `picorv32 #(.ENABLE_COUNTERS(0), .COMPRESSED_ISA(0)) dut (...)`: the device under test, reduced to keep the problem small.
- `init` flag and `assume(!resetn)` while `init`: starts the core in reset.
- `assume(!mem_ready || mem_valid)`: memory only acknowledges a real request.
- `past_valid` flag: ensures `$past(...)` is only used when a previous cycle exists.
- Assertion: if last cycle `mem_valid && !mem_ready`, then this cycle `mem_valid` is still high and `mem_addr`, `mem_wstrb`, `mem_instr` (and `mem_wdata` for writes) are unchanged. In words: a pending request must stay stable until accepted, which is the native memory-interface protocol.
- `cover(resetn && mem_valid && mem_ready && mem_instr)`: a fetch can complete.

**`mem.sby`** (job file):
| Section | Content |
|---|---|
| `[tasks]` | `bmc` and `cover` |
| `[options]` | `mode bmc` / `mode cover`, `depth 30` |
| `[engines]` | `smtbmc boolector` |
| `[script]` | `read_verilog -formal picorv32.v`; `read_verilog -sv -formal formal_mem.sv`; `prep -top formal_mem` |
| `[files]` | `picorv32.v`, `formal_mem.sv` (copied into the job folder) |

`-sv` enables SystemVerilog, `-formal` enables assert/assume support (it defines `FORMAL`; it does **not** enable PicoRV32's `RISCV_FORMAL` RVFI code), and `prep -top` must name the wrapper.

### 9.2 Commands
```bash
sby -f mem.sby bmc
sby -f mem.sby cover
```
`-f` deletes any old result folder first. **bmc** asks whether any 30-cycle input sequence breaks the assertions. **cover** asks whether a fetch can complete.

### 9.3 Results
- `mem_bmc`: assumptions and assertions checked for steps 0 to 29, `Status: passed`, `DONE (PASS, rc=0)` in about 6 seconds.
- `mem_cover`: `Reached cover statement in step 4`, `DONE (PASS, rc=0)`, trace at `mem_cover/engine_0/trace0.vcd`.
- The cover result matters: it shows the assertion is actually exercised, so the proof is not vacuous.
- The message `Latch inferred ... picorv32.v:2118` comes from the stock PicoRV32 source, not from the wrapper.

### 9.4 Return codes
`rc=0` pass; `rc=2` assertion failed (counterexample in `engine_0/trace.vcd`); `rc=4` timeout; `rc=16` script error (usually parse or hierarchy).

**Script:** `scripts/02_mem_formal.sh`.

---

## 10. Step 5: Simulation with Verilator

### 10.1 Theory
Formal reaches only a limited depth. Simulation runs real code for as long as desired but tests only the inputs provided. A **testbench** is the code around the design that supplies clock, reset and memory.

### 10.2 The program (`sim/prog.hex`)
Hand-assembled machine code, one 32-bit instruction per line, so no RISC-V compiler is needed.

| Hex | Assembly | Effect |
|---|---|---|
| `00500093` | `addi x1, x0, 5` | x1 = 5 |
| `00700113` | `addi x2, x0, 7` | x2 = 7 |
| `002081B3` | `add x3, x1, x2` | x3 = 12 |
| `10302023` | `sw x3, 256(x0)` | mem[0x100] = 12 |
| `10002203` | `lw x4, 256(x0)` | x4 = mem[0x100] |
| `100002B7` | `lui x5, 0x10000` | x5 = 0x10000000 |
| `0042A023` | `sw x4, 0(x5)` | write 12 to halt address |
| `0000006F` | `j .` | loop forever |

### 10.3 The testbench (`sim/sim_main.cpp`)
1. Loads `prog.hex` into a 4 KB array.
2. Creates the model, opens `sim.vcd`, holds reset for 10 cycles.
3. Each cycle toggles the clock and acts as memory: answers reads, applies writes honouring `mem_wstrb`, and raises `mem_ready` for the next cycle.
4. A write to `0x10000000` is the halt signal: data 12 gives PASS. `trap` or 2000 cycles without a halt gives FAIL or TIMEOUT.

### 10.4 Commands and flags
```bash
verilator -Wno-fatal --cc --exe --build --trace \
  --top-module picorv32 --Mdir obj_picorv32 \
  picorv32.v sim_main.cpp -o sim_picorv32
./obj_picorv32/sim_picorv32
echo "exit code: $?"
```
`--cc` translates Verilog to C++; `--exe` links the C++ main; `--build` runs `make`; `--trace` records waveforms; `--Mdir` sets the output folder; `-o` names the program. (Verilator 5 requires a C++ main with `--exe`.)

### 10.5 Observed
```
WRITE addr=0x00000100 data=0x0000000c strb=0xf
HALT write: data=0x0000000c
PASS
exit code: 0
```
The core computed 5 + 7 = 12, stored it, reloaded it and wrote it to the halt address. This is a sanity test of 8 instructions, not verification of the instruction set.

### 10.6 Waveform
```bash
gtkwave sim.vcd &
```
`&` keeps the terminal usable; otherwise close the window, press Ctrl+C or run `pkill gtkwave`. The "Glycin running without sandbox" messages are harmless. Useful signals: `clk`, `resetn`, `mem_valid`, `mem_ready`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `trap`.

**Script:** `scripts/05_simulate.sh`.

---

## 11. RVFI in detail

### 11.1 What it is
RVFI (RISC-V Formal Interface) is a standard set of output ports on which a core reports every retired instruction. The checkers treat the core as a black box and judge only this report. To verify a new core you must provide a correct RVFI; the checkers are reusable.

### 11.2 Parameters
`XLEN` register width (32 here), `ILEN` maximum instruction width, `NRET` instructions retired per cycle (1 for simple cores). Each signal has NRET slices; `ch0` is channel 0.

### 11.3 Signals
| Group | Signal | Meaning |
|---|---|---|
| Control | `rvfi_valid` | One-cycle pulse when an instruction retires |
| | `rvfi_order` | Counter incrementing by 1 per retired instruction |
| | `rvfi_insn` | Raw instruction word |
| | `rvfi_trap` | Instruction trapped (must have no side effects) |
| | `rvfi_halt`, `rvfi_intr` | Last instruction before halt; first instruction of a handler |
| | `rvfi_mode`, `rvfi_ixl` | Privilege mode; XLEN encoding (1 = 32-bit, 2 = 64-bit) |
| Registers | `rvfi_rs1_addr/rdata`, `rvfi_rs2_addr/rdata` | Source registers and the values read (0 if unused or x0) |
| | `rvfi_rd_addr/wdata` | Destination and value written (wdata must be 0 if rd is 0) |
| PC | `rvfi_pc_rdata`, `rvfi_pc_wdata` | PC of this instruction; PC of the next |
| Memory | `rvfi_mem_addr`, `rvfi_mem_rmask/rdata`, `rvfi_mem_wmask/wdata` | Address, byte masks, data |

### 11.4 Worked example: `add x3, x1, x2` with x1 = 5, x2 = 7
`rvfi_valid=1`, `rvfi_insn=0x002081B3`, `rs1_addr=1/rdata=5`, `rs2_addr=2/rdata=7`, `rd_addr=3/rd_wdata=12`, `pc_wdata = pc_rdata + 4`, memory masks 0, `rvfi_trap=0`.

### 11.5 Where RVFI sits in this project
| Activity | RVFI used? |
|---|---|
| Verilator lint | No |
| `formal/mem_protocol` bmc and cover | No (bus signals only) |
| riscv-formal checks (87 jobs) | **Yes**, every check reads RVFI |
| Verilator simulation | No |

PicoRV32's RVFI code is compiled in when `RISCV_FORMAL` is defined (set by riscv-formal). Inspect it with:
```bash
grep -n "RISCV_FORMAL" external/picorv32/picorv32.v | head -40
grep -n "rvfi_" external/picorv32/picorv32.v | head -80
less external/riscv-formal/docs/rvfi.md
```

---

## 12. Formal inputs, assumptions and data types

- In simulation each input has one concrete value per cycle. In formal, inputs are **symbolic**: the solver may choose any value each cycle.
- **Free inputs** are declared with `(* anyseq *)` (new value every cycle) or `(* anyconst *)` (chosen once, then fixed). riscv-formal wrappers use the macro `rvformal_rand_reg` for the same purpose.
- **Data types:** ordinary Verilog bit-vectors (1-bit signals, `[31:0]` vectors and so on). No floats or strings; signedness is only an interpretation of the bits. Formal is two-state (0/1); `X` values are replaced by solver-chosen values. Parameters (for example `ENABLE_MUL`) are fixed at elaboration and are not free.
- **Initial state:** a `reg` without initialiser can start with any value; one with an initialiser (`reg init = 1;`) starts fixed. Hence the explicit reset assumption.

| PicoRV32 input | Width | Treatment in `formal_mem.sv` |
|---|---|---|
| `clk` | 1 | Driven by SBY |
| `resetn` | 1 | `anyseq`; forced low in the first cycle |
| `mem_ready` | 1 | `anyseq`; assumed high only when `mem_valid` is high |
| `mem_rdata` | 32 | `anyseq`, unconstrained |
| `irq` | 32 | Left unconnected (free); inert with IRQ disabled |
| `pcpi_wr/rd/wait/ready` | 1/32/1/1 | Left unconnected (free); inert with PCPI disabled |

Outputs (`mem_valid`, `mem_addr`, `trap`, all `rvfi_*`) are produced by the CPU and checked, not chosen by the solver. In the instruction checks the solver chooses the instruction stream through the free memory data, so a pass covers all operands, not only test values.

---

## 13. Role of Verilator in a formal flow

Verilator does not prove anything. It provides:

| Role | Benefit |
|---|---|
| Lint | Independent front end catches width mismatches, latches, multiple drivers, undriven signals |
| Deep simulation | Runs millions of cycles, beyond BMC depth |
| Validating assumptions | A realistic memory model checks that formal assumptions match real use |
| Replaying counterexamples | Reproduce a failing trace as a directed test |
| Reusing assertions | `--assert` checks immediate assertions in long simulations (concurrent SVA support is limited) |
| Co-simulation | Compare the RVFI trace with a reference such as Spike (planned for VEGA) |

Limits: two-state (hides X problems) and tests only what is supplied. Division of labour: formal is exhaustive but shallow; simulation is deep but selective.

---

## 14. How to reproduce everything

Prerequisite: OSS CAD Suite installed (edit `OSS_CAD` in `scripts/env.sh` if not at `~/Downloads/oss-cad-suite`), plus `git`, `python3`, `g++` and `make`.

```bash
git clone <this repository URL> && cd <repository>
scripts/00_fetch_sources.sh      # PicoRV32 + riscv-formal into external/
scripts/01_lint.sh               # Step 2
scripts/02_mem_formal.sh         # Step 4 (seconds)
scripts/03_riscv_formal.sh 4     # Step 3 (tens of minutes to hours; argument = parallel jobs)
scripts/04_summarize.sh          # results CSV and totals
scripts/05_simulate.sh           # Step 5
scripts/record_versions.sh       # tool versions and commits
```
Quick single check:
```bash
source scripts/env.sh
cd external/riscv-formal/cores/picorv32 && python3 ../../checks/genchecks.py
cd checks && sby -f insn_add_ch0.sby
```
If `genchecks.py` or `make` complains about a missing `picorv32.v`, check the contents of `external/riscv-formal/cores/picorv32/` and its Makefile; the layout can differ between riscv-formal versions.

---

## 15. Limitations and honest notes

1. Bounded results only (see 3.3).
2. Only the configuration in `results/checks.cfg.used` was verified (M, C or interrupt checks only if that file enables them).
3. riscv-formal trusts PicoRV32's RVFI implementation; it was not written or reviewed in this work.
4. The own proof checks bus-protocol stability only; it does not assert `trap` behaviour or interrupts.
5. The first memory-proof attempt failed with `FileNotFoundError` because the files had not been created; resolved by creating them.
6. A bug-injection experiment (deliberately breaking an instruction to see a check fail) was **not** performed. It is recommended as future work to demonstrate that the checks detect errors.
7. Statements about checks other than those visible in saved logs (full job list, exact depths) must be taken from `results/` after running the scripts.

---

## 16. Next steps: 64-bit VEGA core

1. Identify the RTL language (Verilog, SystemVerilog or Bluespec), pipeline stages, commit point and bus protocol; confirm modification rights.
2. Parse test: `yosys -p "read_verilog -sv -formal <files>; hierarchy -top <top>; proc; stat"`; lint with Verilator.
3. Implement RVFI under `` `ifdef RISCV_FORMAL ``: XLEN = 64, NRET = 1 (single issue), 8-bit memory masks, `rvfi_ixl = 2`. Carry an RVFI record through every pipeline stage with identical stall and flush behaviour; capture operands after the forwarding mux; compute the true next PC; pulse `rvfi_valid` only at commit.
4. RV64 specifics: W instructions (32-bit compute then sign-extend), 6-bit shift amounts (5-bit for W shifts), `ld`/`sd`/`lwu`.
5. Validate in simulation first: `rvfi_order` continuity, PC chain, comparison with Spike.
6. Create `riscv-formal/cores/vega`: wrapper with bus-protocol assumptions, `checks.cfg` starting at `rv64i`.
7. Staged bring-up: `insn_add`, `insn_addw`, then `reg`, `pc_fwd`, covers, all RV64I, then M (with `ALTOPS`), C, Zicsr, traps and interrupts.
8. Add bug injection to demonstrate detection.

Skills needed: Verilog/SystemVerilog (RTL subset), simple SVA (`assert`, `assume`, `cover`, `$past`), the RISC-V ISA, basic Linux shell and Make, minimal Python.

---

## 17. Glossary

RTL: Verilog description of hardware. Lint: static code checking. Testbench: code that drives a design. Assertion / assumption / cover: see 3.2. Vacuous proof: passes because the checked scenario never occurs. BMC: bounded model checking. SMT solver: Boolector, Z3, Yices. RVFI: RISC-V Formal Interface. Retire: an instruction completes architecturally. VCD: waveform file format. rc: return code. PATH: directories searched for programs. ALTOPS: riscv-formal option replacing multiply/divide logic with simple stand-ins to keep proofs tractable.

---

## 18. Troubleshooting

See `docs/troubleshooting.md`. Most common: `command not found` means the environment was not sourced in this terminal; `FileNotFoundError: mem.sby` means the file does not exist in the current directory.

---

## 19. References and licence

- PicoRV32: https://github.com/YosysHQ/picorv32
- riscv-formal and `docs/rvfi.md`: https://github.com/YosysHQ/riscv-formal
- SymbiYosys: https://symbiyosys.readthedocs.io
- RISC-V specifications: https://riscv.org/specifications/

PicoRV32 and riscv-formal are ISC-licensed by their authors and are not redistributed here. Licence for this repository's own files: [FILL].
