// =====================================================================
// valu.v
// Vector ALU: applies one operation across NUMLANES independent
// 32-bit lanes in parallel (SIMD-style), per RVV spec chapter 11
// ("Vector Integer Arithmetic Instructions"). Elements at or beyond
// `vl` are masked off in vregfile's write (tail-undisturbed), so this
// ALU computes all lanes unconditionally -- simpler hardware, correct
// result because unused lanes are discarded at the write stage.
//
// VecALUOp encoding (chosen for this project, not a spec field itself
// -- derived from {funct6, funct3} by vcontrol.v):
//   000 = vadd.vv     001 = vsub.vv     010 = vand.vv
//   011 = vor.vv      100 = vxor.vv     101 = vmul.vv
// =====================================================================

module valu #(
    parameter VLEN     = 128,
    parameter SEW       = 32,
    parameter NUMLANES  = VLEN / SEW
) (
    input  logic [VLEN-1:0] a, b,
    input  logic [2:0]      VecALUOp,
    output logic [VLEN-1:0] result
);

    genvar i;
    generate
        for (i = 0; i < NUMLANES; i = i + 1) begin : lane
            logic [SEW-1:0] lane_a, lane_b, lane_result;
            assign lane_a = a[i*SEW +: SEW];
            assign lane_b = b[i*SEW +: SEW];

            always_comb begin
                case (VecALUOp)
                    3'b000: lane_result = lane_a + lane_b;   // vadd.vv
                    3'b001: lane_result = lane_a - lane_b;   // vsub.vv
                    3'b010: lane_result = lane_a & lane_b;   // vand.vv
                    3'b011: lane_result = lane_a | lane_b;   // vor.vv
                    3'b100: lane_result = lane_a ^ lane_b;   // vxor.vv
                    3'b101: lane_result = lane_a * lane_b;   // vmul.vv
                    default: lane_result = '0;
                endcase
            end

            assign result[i*SEW +: SEW] = lane_result;
        end
    endgenerate

endmodule
