# Integrating the vector extension

New files (drop into your project folder alongside the existing ones):
- `vregfile.v` — vector register file
- `valu.v` — vector ALU
- `vlreg.v` — vl/vtype state (updated by vsetvli)
- `vcontrol.v` — vector instruction decode
- `vlsu.v` — vector load/store unit (multi-cycle, stalls PC)
- `flopenr.v` — enable+reset flip-flop (new PC register needs this)
- `top_vector.v` — new top-level wiring everything together

Three small, surgical edits are needed in your **existing** files so the
vector unit can (a) stall the PC and (b) read the scalar rs1 value for
`vsetvli`/`vle32.v`/`vse32.v`'s base address / AVL.

---

## 1. `datapath.v` — give the PC an enable, expose SrcA

**Before:**
```verilog
module datapath (
    input  logic        clk, reset,
    input  logic [1:0]  ResultSrc,
    input  logic        PCSrc, ALUSrc,
    input  logic        RegWrite,
    input  logic [1:0]  ImmSrc,
    input  logic [2:0]  ALUControl,
    output logic        Zero,
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic [31:0] ALUResult, WriteData,
    input  logic [31:0] ReadData
);
    ...
    flopr #(32) pcreg (clk, reset, PCNext, PC);
    ...
    regfile rf (clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7],
                Result, SrcA, WriteData);
```

**After:**
```verilog
module datapath (
    input  logic        clk, reset,
    input  logic        PCEn,          // NEW: freezes PC when low
    input  logic [1:0]  ResultSrc,
    input  logic        PCSrc, ALUSrc,
    input  logic        RegWrite,
    input  logic [1:0]  ImmSrc,
    input  logic [2:0]  ALUControl,
    output logic        Zero,
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic [31:0] ALUResult, WriteData,
    output logic [31:0] SrcA,          // NEW: expose rs1 value
    input  logic [31:0] ReadData
);
    ...
    flopenr #(32) pcreg (clk, reset, PCEn, PCNext, PC);   // was flopr
    ...
    regfile rf (clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7],
                Result, SrcA, WriteData);   // SrcA already existed as a
                                             // wire -- just also make it
                                             // a module output now
```

## 2. `riscvsingle.v` — pass PCEn/SrcA through

**Before:**
```verilog
module riscvsingle (
    input  logic        clk, reset,
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic        MemWrite,
    output logic [31:0] ALUResult, WriteData,
    input  logic [31:0] ReadData
);
    ...
    datapath dp (
        clk, reset, ResultSrc, PCSrc,
        ALUSrc, RegWrite,
        ImmSrc, ALUControl,
        Zero, PC, Instr,
        ALUResult, WriteData, ReadData
    );
endmodule
```

**After:**
```verilog
module riscvsingle (
    input  logic        clk, reset,
    input  logic         PCEn,          // NEW
    output logic [31:0] PC,
    input  logic [31:0] Instr,
    output logic        MemWrite,
    output logic [31:0] ALUResult, WriteData,
    output logic [31:0] SrcA,           // NEW
    input  logic [31:0] ReadData
);
    ...
    datapath dp (
        clk, reset, PCEn, ResultSrc, PCSrc,
        ALUSrc, RegWrite,
        ImmSrc, ALUControl,
        Zero, PC, Instr,
        ALUResult, WriteData, SrcA, ReadData
    );
endmodule
```

## 3. `top_vector.v` — wire PCEn = ~Stall

In `top_vector.v`, the `riscvsingle` instantiation needs updating to
actually pass the new ports through (I left this commented in the file
I gave you — uncomment and connect once you've made edits 1 and 2):

```verilog
riscvsingle rvsingle (
    clk, reset, ~Stall, PC, Instr,
    ScalarMemWrite, ScalarDataAdr, ScalarWriteData, ScalarSrcA, ReadData
);
```

---

## Compiling

```bash
iverilog -g2012 -o vsim \
  riscvsingle.v controller.v maindec.v aludec.v datapath.v \
  flopr.v flopenr.v adder.v mux2.v mux3.v regfile.v extend.v alu.v \
  vregfile.v valu.v vlreg.v vcontrol.v vlsu.v \
  top_vector.v imem.v dmem.v your_testbench.v
```

## What's NOT implemented (roadmap, referencing riscv-v-spec chapters)

- Variable VLEN / SEW / LMUL (spec ch. 3-4) — everything here is fixed
  at VLEN=128, SEW=32, LMUL=1
- Masking (`vm=0` case, spec ch. 5) — always behaves as if `vm=1`
- Tail/mask agnostic vs. undisturbed policies (spec ch. 5.3-5.4) —
  only "undisturbed" is modeled, and only for tail elements
- Strided / indexed / segment loads-stores (spec ch. 7.4-7.8) —
  unit-stride only
- Reductions, permutations, mask instructions (spec ch. 12-16)
- Fixed-point and floating-point vector ops (spec ch. 13, 14)
- CSR-based `vtype`/`vl`/`vstart` (spec ch. 3.7-3.9, 9) — this uses a
  plain register, not real CSRs

Reference: https://github.com/riscv/riscv-v-spec
