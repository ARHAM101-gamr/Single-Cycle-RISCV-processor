// =====================================================================
// vregfile.v
// Vector register file per RVV spec section 3 ("Vector Register State").
// 32 vector registers, each VLEN bits wide. This implementation fixes
// VLEN = 128 (4 x 32-bit lanes), matching our fixed SEW = 32, LMUL = 1
// scope. Real RVV implementations parameterize VLEN and support
// LMUL > 1 (register grouping) -- out of scope here.
//
// Write policy: "tail-undisturbed" simplification -- only the first
// `vl` elements (of NUMLANES) are updated on a write; elements at or
// beyond vl keep their old value. (Full RVV also has mask-undisturbed
// and vta/vma agnostic policies -- not modeled here.)
// =====================================================================

module vregfile #(
    parameter VLEN     = 128,
    parameter SEW       = 32,
    parameter NUMLANES  = VLEN / SEW   // = 4
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic [4:0]            vs1, vs2, vd,
    input  logic [$clog2(NUMLANES+1)-1:0] vl,      // active element count
    input  logic [VLEN-1:0]       wdata,
    output logic [VLEN-1:0]       rdata1, rdata2
);

    logic [VLEN-1:0] vregs [0:31];

    assign rdata1 = vregs[vs1];
    assign rdata2 = vregs[vs2];

    integer i;
    always_ff @(posedge clk) begin
        if (we) begin
            for (i = 0; i < NUMLANES; i = i + 1) begin
                if (i < vl)
                    vregs[vd][i*SEW +: SEW] <= wdata[i*SEW +: SEW];
                // else: element i untouched (tail-undisturbed)
            end
        end
    end

endmodule
