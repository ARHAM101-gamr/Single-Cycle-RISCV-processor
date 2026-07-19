// =====================================================================
// extend.v
// Sign-extends immediates for I, S, B, and J instruction formats.
// =====================================================================

module extend (
    input  logic [31:7] instr,
    input  logic [1:0]  immsrc,
    output logic [31:0] immext
);
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    assign immext = (immsrc == 2'b00) ? imm_i :
                     (immsrc == 2'b01) ? imm_s :
                     (immsrc == 2'b10) ? imm_b :
                     (immsrc == 2'b11) ? imm_j : 32'b0;
endmodule
