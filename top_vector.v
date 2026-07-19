// =====================================================================
// top_vector.v
// Top-level harness for the scalar core + vector extension. Wires:
//   - riscvsingle (your existing scalar core, with ONE required edit:
//     PC register needs an enable input -- see integration notes)
//   - imem / dmem (existing, unchanged; dmem port is now shared and
//     arbitrated between the scalar core and the vector LSU)
//   - vcontrol   (decodes vector instructions)
//   - vlreg      (vl/vtype state, updated by vsetvli)
//   - vregfile   (vector register file)
//   - valu       (vector ALU, for arithmetic vector ops)
//   - vlsu       (vector load/store unit, multi-cycle, stalls PC)
//
// NOTE ON rs1 FOR vsetvli/vle/vse: the scalar register file already
// holds the general-purpose registers. This wrapper needs to read the
// scalar regfile's rs1 value (for vsetvli's AVL and for vle/vse's base
// address). Your current riscvsingle does not expose SrcA externally,
// so this file assumes you add that one output too (see notes below).
// =====================================================================

module top_vector (
    input  logic        clk, reset
);

    localparam VLEN    = 128;
    localparam SEW      = 32;
    localparam NUMLANES = VLEN / SEW;

    // ------------------------------------------------------------
    // Scalar core <-> memory signals
    // ------------------------------------------------------------
    logic [31:0] PC, Instr;
    logic         ScalarMemWrite;
    logic [31:0] ScalarDataAdr, ScalarWriteData, ReadData;
    logic [31:0] ScalarSrcA;     // rs1 value -- requires exposing SrcA (see notes)

    // ------------------------------------------------------------
    // Vector control / state
    // ------------------------------------------------------------
    logic        IsVectorOp, IsVsetvli, IsVArith, IsVLoad, IsVStore;
    logic [2:0]  VecALUOp;
    logic        VecRegWrite;
    logic [$clog2(NUMLANES+1)-1:0] vl;

    logic        Stall;

    vcontrol vctrl (
        .Instr       (Instr),
        .IsVectorOp  (IsVectorOp),
        .IsVsetvli   (IsVsetvli),
        .IsVArith    (IsVArith),
        .IsVLoad     (IsVLoad),
        .IsVStore    (IsVStore),
        .VecALUOp    (VecALUOp),
        .VecRegWrite (VecRegWrite)
    );

    vlreg #(.NUMLANES(NUMLANES)) vlreg_inst (
        .clk        (clk),
        .reset      (reset),
        .VsetvliEn  (IsVsetvli),
        .rs1_val    (ScalarSrcA),
        .rs1_is_x0  (Instr[19:15] == 5'b0),
        .vl         (vl)
    );

    // ------------------------------------------------------------
    // Vector register file
    // vs2 read port is reused as the store-source (vs3) port on a
    // vector store, since vs3 shares the same field position (11:7)
    // that vd normally occupies.
    // ------------------------------------------------------------
    logic [4:0] vs2_or_vs3;
    assign vs2_or_vs3 = IsVStore ? Instr[11:7] : Instr[24:20];

    logic [VLEN-1:0] vrf_rdata1, vrf_rdata2;
    logic [VLEN-1:0] vrf_wdata;
    logic             vrf_we;

    vregfile #(.VLEN(VLEN), .SEW(SEW)) vregfile_inst (
        .clk    (clk),
        .we     (vrf_we),
        .vs1    (Instr[19:15]),
        .vs2    (vs2_or_vs3),
        .vd     (Instr[11:7]),
        .vl     (vl),
        .wdata  (vrf_wdata),
        .rdata1 (vrf_rdata1),
        .rdata2 (vrf_rdata2)
    );

    // ------------------------------------------------------------
    // Vector ALU
    // ------------------------------------------------------------
    logic [VLEN-1:0] valu_result;

    valu #(.VLEN(VLEN), .SEW(SEW)) valu_inst (
        .a        (vrf_rdata1),
        .b        (vrf_rdata2),
        .VecALUOp (VecALUOp),
        .result   (valu_result)
    );

    // ------------------------------------------------------------
    // Vector load/store unit -- drives dmem when active
    // ------------------------------------------------------------
    logic [31:0] vlsu_addr, vlsu_wd;
    logic         vlsu_we;
    logic [VLEN-1:0] vlsu_load_data;
    logic         vlsu_done, vlsu_stall;

    vlsu #(.VLEN(VLEN), .SEW(SEW)) vlsu_inst (
        .clk        (clk),
        .reset      (reset),
        .IsLoad     (IsVLoad),
        .IsStore    (IsVStore),
        .base_addr  (ScalarSrcA),
        .vl         (vl),
        .store_data (vrf_rdata2),
        .dmem_rd    (ReadData),
        .dmem_addr  (vlsu_addr),
        .dmem_wd    (vlsu_wd),
        .dmem_we    (vlsu_we),
        .load_data  (vlsu_load_data),
        .Done       (vlsu_done),
        .Stall      (vlsu_stall)
    );

    assign Stall = vlsu_stall;

    // ------------------------------------------------------------
    // Vector register file write mux: arithmetic result (1 cycle) or
    // assembled load result (on vlsu_done pulse)
    // ------------------------------------------------------------
    assign vrf_wdata = IsVLoad ? vlsu_load_data : valu_result;
    assign vrf_we    = (IsVArith && VecRegWrite) || vlsu_done;

    // ------------------------------------------------------------
    // Shared data memory arbitration: vector LSU owns the bus
    // whenever it's active (IsVLoad/IsVStore); otherwise scalar core
    // drives it as normal.
    // ------------------------------------------------------------
    logic [31:0] DataAdr, WriteData;
    logic         MemWrite;
    wire vector_owns_bus = IsVLoad || IsVStore;

    assign DataAdr   = vector_owns_bus ? vlsu_addr    : ScalarDataAdr;
    assign WriteData = vector_owns_bus ? vlsu_wd      : ScalarWriteData;
    assign MemWrite  = vector_owns_bus ? vlsu_we       : ScalarMemWrite;

    // ------------------------------------------------------------
    // Scalar core + memories
    // ------------------------------------------------------------
    riscvsingle rvsingle (
        clk, reset, PC, Instr,
        ScalarMemWrite, ScalarDataAdr, ScalarWriteData, ReadData
        // , ScalarSrcA   -- add this output per integration notes
        // , Stall        -- add this input per integration notes
    );

    imem imem_inst (PC, Instr);
    dmem dmem_inst (clk, MemWrite, DataAdr, WriteData, ReadData);

endmodule
