// =====================================================================
// aludec.v
// ALU decoder: produces the 3-bit ALUControl signal.
// =====================================================================

module aludec (
    input  logic       opb5,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic [1:0] ALUOp,
    output logic [2:0] ALUControl
);

    logic RtypeSub, RtypeMul;
    assign RtypeSub = opb5 & (funct7 == 7'b0100000);
    assign RtypeMul = opb5 & (funct7 == 7'b0000001);

    always_comb begin
        case (ALUOp)
            2'b00: ALUControl = 3'b000; // add (lw, sw, addi)
            2'b01: ALUControl = 3'b001; // subtract (beq)
            default: begin
                case (funct3)
                    3'b000: ALUControl = RtypeMul ? 3'b100 : RtypeSub ? 3'b001 : 3'b000; // mul : sub : add
                    3'b010: ALUControl = 3'b101; // slt
                    3'b110: ALUControl = 3'b011; // or
                    3'b111: ALUControl = 3'b010; // and
                    default: ALUControl = 3'b000;
                endcase
            end
        endcase
    end

endmodule
