// =====================================================================
// alu.v
// Performs add, subtract, mul, and, or, slt based on ALUControl.
// Division is not supported in this processor.
// =====================================================================

module alu (
    input  logic [31:0] a, b,
    input  logic [2:0]  alucontrol,
    output logic [31:0] result,
    output logic        zero
);
    logic [31:0] condinvb, sum;
    logic        isAddSub;

    assign condinvb = alucontrol[0] ? ~b : b;
    assign sum = a + condinvb + alucontrol[0];
    assign isAddSub = (alucontrol == 3'b000) | (alucontrol == 3'b001);

    wire [31:0] slt_result = {31'b0, sum[31] ^ ((a[31]^b[31]) & isAddSub)};

    assign result = (alucontrol == 3'b000) ? sum :        // add
                     (alucontrol == 3'b001) ? sum :        // subtract
                     (alucontrol == 3'b100) ? (a * b) :    // mul
                     (alucontrol == 3'b010) ? (a & b) :    // and
                     (alucontrol == 3'b011) ? (a | b) :    // or
                     (alucontrol == 3'b101) ? slt_result :  // slt
                     32'b0;

    assign zero = (result == 32'b0);
endmodule