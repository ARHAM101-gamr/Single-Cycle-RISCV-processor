// =====================================================================
// regfile.v
// 32 x 32-bit RISC-V register file. x0 is hardwired to read as 0.
// =====================================================================

module regfile (
    input  logic        clk,
    input  logic        we3,
    input  logic [4:0]  a1, a2, a3,
    input  logic [31:0] wd3,
    output logic [31:0] rd1, rd2
);
    logic [31:0] rf [0:31];

    always_ff @(posedge clk)
        if (we3 && a3 != 0)
            rf[a3] <= wd3;

    assign rd1 = (a1 == 0) ? 32'b0 : rf[a1];
    assign rd2 = (a2 == 0) ? 32'b0 : rf[a2];
endmodule
