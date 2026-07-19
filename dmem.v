// =====================================================================
// dmem.v
// Data memory. Word-addressed internally, byte-addressed on the
// address input (a[31:2] selects the word). Synchronous write,
// asynchronous (combinational) read.
// =====================================================================

module dmem (
    input  logic        clk, we,
    input  logic [31:0] a, wd,
    output logic [31:0] rd
);
    logic [31:0] RAM[0:63];

    assign rd = RAM[a[31:2]];   // word-aligned read

    always_ff @(posedge clk)
        if (we) RAM[a[31:2]] <= wd;

endmodule
