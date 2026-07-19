// =====================================================================
// imem.v
// Instruction memory. Word-addressed internally, byte-addressed on
// the PC input (PC[31:2] selects the word). Loaded from imem.hex at
// time 0 using $readmemh.
// =====================================================================

module imem (
    input  logic [31:0] a,      // address (from PC)
    output logic [31:0] rd      // instruction out
);
    logic [7:0] RAM[0:255];

    initial
        $readmemh("imem.hex", RAM);

    // Assemble little-endian bytes into a 32-bit instruction word.
    assign rd = {RAM[{a[31:2], 2'b11}],
                 RAM[{a[31:2], 2'b10}],
                 RAM[{a[31:2], 2'b01}],
                 RAM[{a[31:2], 2'b00}]};

endmodule
