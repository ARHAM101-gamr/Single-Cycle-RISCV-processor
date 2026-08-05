# RISC-V Processor: Single-Cycle Core → 5-Stage Pipeline

A from-scratch implementation of a RISC-V processor in Verilog, built as a Final Year Project. The project starts with a **single-cycle datapath** (Harris & Harris style, limited RV32I subset) and documents its evolution into a **5-stage pipelined** implementation.

> **Note:** This README is a starting template based on the project's current scope. Update the file structure, instruction list, and results sections with your actual repo contents before publishing.

---

## Table of Contents
- [Overview](#overview)
- [Part 1: Single-Cycle Processor](#part-1-single-cycle-processor)
- [Part 2: Evolution to 5-Stage Pipeline](#part-2-evolution-to-5-stage-pipeline)
- [Repository Structure](#repository-structure)
- [Toolchain & Build Instructions](#toolchain--build-instructions)
- [Simulation Workflow](#simulation-workflow)
- [Instruction Set Coverage](#instruction-set-coverage)
- [Results & Waveforms](#results--waveforms)
- [Future Work](#future-work)
- [References](#references)

---

## Overview

This project implements a subset of the **RV32I base integer instruction set** in Verilog HDL, following the classic datapath design taught in *Digital Design and Computer Architecture* (Harris & Harris). It is developed and verified in two stages:

1. **Single-Cycle Processor** — every instruction completes in exactly one clock cycle. Simple to design and verify, but clock speed is bottlenecked by the slowest instruction (typically loads/stores).
2. **5-Stage Pipelined Processor** — the same datapath is split into **Fetch → Decode → Execute → Memory → Writeback** stages, with pipeline registers, hazard detection, and forwarding added to resolve data and control hazards introduced by pipelining.

The goal is to demonstrate, in hardware, the classic architectural trade-off between single-cycle simplicity and pipelined throughput.

---

## Part 1: Single-Cycle Processor

### Architecture

The single-cycle datapath consists of the standard components:

- **Program Counter (PC)** — updated every cycle (PC+4 or branch/jump target)
- **Instruction Memory (`imem`)** — combinational read, addressed by PC
- **Register File** — 32 × 32-bit registers, 2 read ports / 1 write port
- **ALU** — supports arithmetic, logic, and comparison operations required by the ISA subset
- **Data Memory (`dmem`)** — for `LW`/`SW` style load/store instructions
- **Control Unit** — combinational decode of `opcode`/`funct3`/`funct7` into control signals (`RegWrite`, `MemWrite`, `ALUSrc`, `ResultSrc`, `Branch`, `Jump`, etc.)
- **Immediate Generator** — sign-extends and formats immediates for I/S/B/U/J instruction types

Since everything happens combinationally within one clock edge, there are **no pipeline hazards** to handle — correctness only requires the control signals and datapath muxes to be wired correctly for each instruction type.

### Verification

The single-cycle core is verified with a self-checking testbench:

| File | Purpose |
|---|---|
| `top.v` | Top-level module instantiating the processor, `imem`, and `dmem` |
| `imem.v` | Instruction memory, loads `imem.hex` at simulation start |
| `dmem.v` | Data memory model |
| `testbench.v` | Drives the clock/reset, checks results (e.g., writes to a known memory address on success) |
| `imem.hex` | Compiled program, loaded via `$readmemh` |

Test programs are written in C, cross-compiled to RV32I machine code, and converted to a `.hex` file consumable by `$readmemh`. Because the processor implements only a limited instruction subset, **every compiled binary is inspected with `objdump -d`** before use to confirm the compiler didn't emit unsupported instructions (e.g., pseudo-ops, compressed instructions, or extensions like M/A/F).

---

## Part 2: Evolution to 5-Stage Pipeline

Converting the single-cycle design into a pipeline reuses the same functional blocks (ALU, register file, control unit, immediate generator) but restructures the datapath around five overlapping stages:

| Stage | Abbreviation | Function |
|---|---|---|
| Fetch | **IF** | Read instruction from `imem` at PC, compute PC+4 |
| Decode | **ID** | Register file read, immediate generation, control signal decode |
| Execute | **EX** | ALU operation, branch target/condition resolution |
| Memory | **MEM** | Data memory read/write for loads and stores |
| Writeback | **WB** | Write ALU result or memory data back to register file |

### Key additions over the single-cycle design

1. **Pipeline Registers** — `IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB` latches carry instruction data and control signals forward each cycle so five instructions can be in flight simultaneously.
2. **Hazard Detection Unit** — detects:
   - **Data hazards** (RAW): an instruction needs a register value that hasn't been written back yet.
   - **Load-use hazard**: a `LW` immediately followed by an instruction using its destination register requires a one-cycle stall, since the loaded value isn't available until MEM.
3. **Forwarding (Bypass) Unit** — forwards ALU results from `EX/MEM` and `MEM/WB` pipeline registers directly to the ALU inputs in EX, avoiding stalls in most RAW hazard cases.
4. **Stall & Flush Logic**:
   - **Stalls** freeze `PC` and `IF/ID`, and insert a bubble (NOP) into `ID/EX` when a load-use hazard is detected.
   - **Flushes** clear `IF/ID` (and sometimes `ID/EX`) when a branch/jump is resolved as taken, discarding incorrectly fetched instructions.
5. **Control Hazard Handling** — since branch outcomes are resolved in EX (not IF), a naive pipeline fetches 1–2 wrong instructions per taken branch. This is handled via:
   - Flushing on branch resolution (simplest, adds bubbles), and/or
   - Static/dynamic branch prediction (stretch goal — see [Future Work](#future-work)).

### Design Comparison

| Aspect | Single-Cycle | 5-Stage Pipeline |
|---|---|---|
| Clock period | Set by slowest instruction (usually `LW`) | Set by slowest **stage** — much shorter |
| Throughput | 1 instruction / N cycles (N = critical path) | ~1 instruction / cycle (ideal, no hazards) |
| Hardware reuse | Each unit used once per instruction | Each unit used every cycle (needs separate stage-local versions where reuse would conflict) |
| Hazards | None (no overlap) | Data hazards, load-use hazards, control hazards |
| Complexity | Low — control logic only | Higher — hazard detection, forwarding, flushing |

---

## Repository Structure

```
.
├── single_cycle/
│   ├── top.v
│   ├── imem.v
│   ├── dmem.v
│   ├── datapath.v
│   ├── controller.v
│   └── testbench.v
├── pipeline/
│   ├── top.v
│   ├── if_stage.v
│   ├── id_stage.v
│   ├── ex_stage.v
│   ├── mem_stage.v
│   ├── wb_stage.v
│   ├── hazard_unit.v
│   ├── forwarding_unit.v
│   └── testbench.v
├── software/
│   ├── test1.c
│   ├── test1.hex
│   └── ...
└── README.md
```
*(Update this tree to match your actual folder layout.)*

---

## Toolchain & Build Instructions

### Prerequisites
- **Verilog simulator**: Icarus Verilog (`iverilog`) or ModelSim/Questa
- **Waveform viewer**: GTKWave
- **RISC-V cross-compiler**: `gcc-riscv64-linux-gnu` (via WSL on Windows)

### Windows / WSL note
On Windows, the RV32I cross-compiler is easiest to run under **WSL**, since native Windows RISC-V GCC builds are inconsistent. Project files on the Windows side are reachable from WSL at a path like `/mnt/d/<project-folder>`.

### C-to-Hex Pipeline

```bash
# 1. Compile C to a bare-metal RV32I ELF (no standard library)
riscv64-linux-gnu-gcc -march=rv32i -mabi=ilp32 -nostdlib -O0 -c test1.c -o test1.o

# 2. Link into a flat ELF at the expected base address
riscv64-linux-gnu-ld -Ttext 0x0 test1.o -o test1.elf

# 3. Inspect the disassembly — confirm only supported instructions were emitted
riscv64-linux-gnu-objdump -d test1.elf

# 4. Extract raw machine code and convert to hex for $readmemh
riscv64-linux-gnu-objcopy -O binary test1.elf test1.bin
xxd -p -c4 test1.bin > test1.hex
```

> Always run `objdump -d` before simulating — the processor supports a **limited RV32I subset**, and unsupported instructions will silently produce wrong results rather than an error.

---

## Simulation Workflow

```bash
# Single-cycle
cd single_cycle
iverilog -o sim top.v datapath.v controller.v imem.v dmem.v testbench.v
vvp sim
gtkwave dump.vcd

# Pipeline
cd pipeline
iverilog -o sim top.v if_stage.v id_stage.v ex_stage.v mem_stage.v wb_stage.v hazard_unit.v forwarding_unit.v testbench.v
vvp sim
gtkwave dump.vcd
```

The testbench writes a known "success" value to a specific data memory address when all test instructions complete correctly — check the console output or the corresponding waveform signal to confirm a passing run.

---

## Instruction Set Coverage

*(Fill in with your actual supported instructions.)*

| Type | Instructions |
|---|---|
| R-type | `add`, `sub`, `and`, `or`, `xor`, `slt`, ... |
| I-type | `addi`, `lw`, `andi`, `ori`, `slti`, ... |
| S-type | `sw` |
| B-type | `beq`, `bne`, ... |
| U-type | `lui`, `auipc` |
| J-type | `jal` |

---

## Results & Waveforms

*(Add screenshots/GIFs of GTKWave output, cycle counts for single-cycle vs. pipeline on the same test program, and any CPI/IPC measurements here.)*

---

## Future Work

- [ ] Branch prediction (static "predict not-taken" or a simple BHT)
- [ ] Full RV32I instruction coverage
- [ ] Hazard/forwarding coverage report (which hazard cases are tested)
- [ ] Synthesis + timing analysis to quantify clock period improvement over single-cycle
- [ ] Optional: extend to RV32IM (multiply/divide)

---

## References

- Sarah L. Harris & David Money Harris, *Digital Design and Computer Architecture: RISC-V Edition*
- [RISC-V ISA Specifications](https://riscv.org/technical/specifications/)
