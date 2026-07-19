// =====================================================================
// vlsu.v
// Vector load/store unit, per RVV spec chapter 7 ("Vector Loads and
// Stores"), unit-stride only (vle32.v / vse32.v), this scope's fixed
// SEW=32 / NUMLANES=4.
//
// IMPORTANT ARCHITECTURAL NOTE: the scalar core is single-cycle by
// design -- one memory access per instruction. A vector load/store
// needs up to NUMLANES memory accesses. This unit is a small
// multi-cycle coprocessor that takes over the shared dmem port and
// asserts `Stall` to freeze the scalar PC (via a modified pcreg with
// an enable, see flopenr.v) for (vl) extra cycles while it walks
// through elements one at a time. This is a common, honest way to
// add a vector unit to a single-cycle core without redesigning the
// whole memory system to be VLEN-wide.
//
// This is a first-pass, pedagogical FSM -- verify carefully in
// simulation before trusting it; edge cases (vl=0, back-to-back
// vector ops) deserve extra test cases.
// =====================================================================

module vlsu #(
    parameter VLEN     = 128,
    parameter SEW       = 32,
    parameter NUMLANES  = VLEN / SEW
) (
    input  logic                          clk, reset,
    input  logic                          IsLoad, IsStore,   // from vcontrol
    input  logic [31:0]                   base_addr,          // rs1 value
    input  logic [$clog2(NUMLANES+1)-1:0] vl,
    input  logic [VLEN-1:0]               store_data,         // vs3 (source vreg for store)
    input  logic [31:0]                   dmem_rd,            // shared dmem read data

    output logic [31:0]                   dmem_addr,
    output logic [31:0]                   dmem_wd,
    output logic                          dmem_we,
    output logic [VLEN-1:0]               load_data,          // assembled result, for load
    output logic                          Done,               // 1-cycle pulse: write vregfile now
    output logic                          Stall
);

    localparam IDXW = (NUMLANES <= 1) ? 1 : $clog2(NUMLANES);

    logic                busy;
    logic [IDXW-1:0]     idx;
    logic [VLEN-1:0]     load_buf;

    wire starting = (IsLoad || IsStore) && !busy && (vl != 0);

    // ------------------------------------------------------------
    // Drive the shared dmem port combinationally based on current idx
    // ------------------------------------------------------------
    assign dmem_addr = base_addr + ((busy ? idx : {IDXW{1'b0}}) * (SEW/8));
    assign dmem_wd    = store_data[(busy ? idx : {IDXW{1'b0}})*SEW +: SEW];
    assign dmem_we    = busy && IsStore;

    assign load_data = load_buf;
    assign Stall      = busy || starting;
    // Done pulses on the cycle the *last* element is being processed
    // (its result becomes valid at this posedge's completion)
    assign Done = busy && IsLoad && (idx == vl - 1);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            idx  <= {IDXW{1'b0}};
            load_buf <= '0;
        end else begin
            if (!busy) begin
                if (starting) begin
                    busy <= 1'b1;
                    idx  <= {IDXW{1'b0}};
                end
            end else begin
                if (IsLoad)
                    load_buf[idx*SEW +: SEW] <= dmem_rd;

                if (idx == vl - 1) begin
                    busy <= 1'b0;
                    idx  <= {IDXW{1'b0}};
                end else begin
                    idx <= idx + 1'b1;
                end
            end
        end
    end

endmodule
