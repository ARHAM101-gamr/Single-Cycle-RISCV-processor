// =====================================================================
// top.v
// Top-level test harness: wires the riscvsingle processor to an
// instruction memory (imem) and data memory (dmem).
// =====================================================================

module top (
    input  logic        clk, reset,
    output logic [31:0] WriteData, DataAdr,
    output logic         MemWrite
);
    logic [31:0] PC, Instr, ReadData;

    riscvsingle rvsingle (
        clk, reset, PC, Instr,
        MemWrite, DataAdr, WriteData, ReadData
    );

    imem imem_inst (PC, Instr);

    dmem dmem_inst (clk, MemWrite, DataAdr, WriteData, ReadData);

endmodule
