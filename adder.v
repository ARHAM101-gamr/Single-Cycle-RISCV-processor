// =====================================================================
// adder.v
// Simple 32-bit adder. Used for PC+4 and branch target calculation.
// =====================================================================

module adder (
    input  logic [31:0] a, b,
    output logic [31:0] y
);
    assign y = a + b;
endmodule
