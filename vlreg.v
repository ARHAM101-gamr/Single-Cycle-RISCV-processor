// =====================================================================
// vlreg.v
// Minimal vl/vtype state, per RVV spec sections 3.7-3.9. Real RVV has
// a much richer vtype (vill, vma, vta, vlmul[2:0], vsew[2:0]) and vl
// can be any value up to VLMAX for the selected SEW/LMUL. Here SEW is
// fixed at 32 and LMUL at 1, so VLMAX = NUMLANES is constant, and the
// only thing vsetvli really does in this scope is clamp the requested
// AVL (application vector length) down to VLMAX.
//
// vsetvli rd, rs1, zimm  (RVV spec ch. 6, "vsetvli" encoding):
//   Instr[31]    = 0            (distinguishes from vsetvl/vsetivli)
//   Instr[30:20] = zimm[10:0]   (encodes vtype; we only look at SEW bits)
//   Instr[19:15] = rs1          (AVL, requested vector length)
//   Instr[14:12] = funct3 = 111 (OPCFG)
//   Instr[11:7]  = rd
//
// Two AVL cases implemented (per spec 6.1):
//   rs1 != x0 : vl = min(AVL, VLMAX)
//   rs1 == x0 : vl = VLMAX               (rd == x0 "keep vl" case omitted)
// =====================================================================

module vlreg #(
    parameter NUMLANES = 4
) (
    input  logic                          clk, reset,
    input  logic                          VsetvliEn,
    input  logic [31:0]                   rs1_val,   // AVL from scalar regfile
    input  logic                          rs1_is_x0,
    output logic [$clog2(NUMLANES+1)-1:0] vl
);

    localparam VLMAX = NUMLANES;

    logic [$clog2(NUMLANES+1)-1:0] vl_next;

    always_comb begin
        if (rs1_is_x0)
            vl_next = VLMAX[$clog2(NUMLANES+1)-1:0];
        else
            vl_next = (rs1_val > VLMAX) ? VLMAX[$clog2(NUMLANES+1)-1:0]
                                         : rs1_val[$clog2(NUMLANES+1)-1:0];
    end

    always_ff @(posedge clk or posedge reset)
        if (reset)          vl <= VLMAX[$clog2(NUMLANES+1)-1:0]; // reset default: max
        else if (VsetvliEn) vl <= vl_next;

endmodule
