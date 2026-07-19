// =====================================================================
// flopenr.v
// Resettable, clock-enabled D flip-flop, parameterized width.
// Same as your existing flopr.v but with an added enable input --
// needed so the vector unit can freeze the PC (en = ~Stall) while a
// multi-cycle vector load/store is in progress.
// =====================================================================

module flopenr #(parameter WIDTH = 8) (
    input  logic             clk, reset, en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or posedge reset)
        if (reset)   q <= '0;
        else if (en) q <= d;
endmodule
