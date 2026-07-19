// =====================================================================
// vcontrol.v
// Decodes the vector subset of the instruction stream. Uses the
// official RVV major opcodes (spec ch. 6):
//   OP-V      = 1010111  (arithmetic + vsetvli, distinguished by funct3)
//   LOAD-FP   = 0000111  (vector unit-stride load, this scope only)
//   STORE-FP  = 0100111  (vector unit-stride store, this scope only)
// These opcodes do not collide with the scalar RV32I opcodes already
// used in maindec.v (LOAD=0000011, STORE=0100011, OP=0110011), so the
// scalar decoder needs no changes -- just OR in "not a vector op" as
// a qualifier if you want to be defensive.
// =====================================================================

module vcontrol (
    input  logic [31:0] Instr,
    output logic         IsVectorOp,   // any recognized vector instruction
    output logic         IsVsetvli,
    output logic         IsVArith,
    output logic         IsVLoad,
    output logic         IsVStore,
    output logic [2:0]   VecALUOp,
    output logic         VecRegWrite
);

    logic [6:0] op;
    logic [2:0] funct3;
    logic [5:0] funct6;

    assign op     = Instr[6:0];
    assign funct3 = Instr[14:12];
    assign funct6 = Instr[31:26];

    // OP-V major opcode: vsetvli vs. arithmetic distinguished by funct3
    wire is_opv     = (op == 7'b1010111);
    assign IsVsetvli = is_opv && (funct3 == 3'b111);
    assign IsVArith  = is_opv && (funct3 == 3'b000 || funct3 == 3'b010); // OPIVV / OPMVV

    // Unit-stride vector load/store, 32-bit element width only (width=110),
    // mop=00 (unit-stride), lumop/sumop=00000 (plain, not FF/whole-reg)
    assign IsVLoad  = (op == 7'b0000111) && (funct3 == 3'b110) &&
                       (Instr[27:26] == 2'b00) && (Instr[24:20] == 5'b00000);
    assign IsVStore = (op == 7'b0100111) && (funct3 == 3'b110) &&
                       (Instr[27:26] == 2'b00) && (Instr[24:20] == 5'b00000);

    assign IsVectorOp = IsVsetvli | IsVArith | IsVLoad | IsVStore;

    assign VecRegWrite = IsVArith | IsVLoad;

    // Map {funct6, funct3} to our internal VecALUOp encoding.
    // funct3 = 000 -> OPIVV (integer vector-vector); 010 -> OPMVV (mul)
    always_comb begin
        case ({funct6, funct3})
            {6'b000000, 3'b000}: VecALUOp = 3'b000; // vadd.vv
            {6'b000010, 3'b000}: VecALUOp = 3'b001; // vsub.vv
            {6'b001001, 3'b000}: VecALUOp = 3'b010; // vand.vv
            {6'b001010, 3'b000}: VecALUOp = 3'b011; // vor.vv
            {6'b001011, 3'b000}: VecALUOp = 3'b100; // vxor.vv
            {6'b100101, 3'b010}: VecALUOp = 3'b101; // vmul.vv
            default:              VecALUOp = 3'b000;
        endcase
    end

endmodule
