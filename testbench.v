// =====================================================================
// testbench.v
// Self-checking testbench for the single-cycle RISC-V processor.
//
// Loads the program in imem.hex (see instr_listing.txt for the
// assembly / machine code) and runs it to completion. The program
// exercises addi, add, sub, and, or, slt, beq (taken + not-taken),
// sw, lw, and jal, then halts by branching to itself (beq x0,x0,0).
//
// Expected architectural state at halt (word address 88 / PC=88):
//   x2 = 23   x3 = 12   x4 = 0   x5 = 11
//   x6 = 2    x7 = 6    x9 = 17  mem[96] = 6
// =====================================================================

module testbench();

    logic        clk;
    logic        reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    // instantiate device under test
    top dut (clk, reset, WriteData, DataAdr, MemWrite);

    // generate clock: 10ns period
    always begin
        clk = 1'b0; #5;
        clk = 1'b1; #5;
    end

    // generate reset pulse
    initial begin
        reset = 1'b1;
        #22;
        reset = 1'b0;
    end

    // check results: whenever the processor performs the store to
    // address 96 (mem[96] = x7 = 6), verify the value being written
    always @(negedge clk)
        if (MemWrite)
            if (DataAdr === 32'd96) begin
                if (WriteData === 32'd6) begin
                    $display("Store check PASSED: mem[96] <= %0d at time %0t",
                              WriteData, $time);
                end else begin
                    $display("Store check FAILED: mem[96] <= %0d (expected 6) at time %0t",
                              WriteData, $time);
                    $stop;
                end
            end else begin
                $display("FAILED: unexpected store to address %0d, data %0d, at time %0t",
                          DataAdr, WriteData, $time);
                $stop;
            end

    // detect halt condition: PC stops changing because the last
    // instruction is beq x0, x0, 0 (branches to itself)
    logic [31:0] PCprev;
    integer      idle_count;
    initial idle_count = 0;

    always @(negedge clk) begin
        if (reset) begin
            PCprev    <= 32'hFFFF_FFFF;
            idle_count <= 0;
        end else begin
            if (dut.rvsingle.PC === PCprev)
                idle_count <= idle_count + 1;
            else
                idle_count <= 0;
            PCprev <= dut.rvsingle.PC;

            // once PC has been steady for a few cycles, the self-loop
            // (halt) instruction has been reached: check final register
            // file state and finish
            if (idle_count == 3) begin
                check_registers;
                $display("All tests PASSED at time %0t (PC = %0d)", $time, dut.rvsingle.PC);
                $finish;
            end
        end
    end

    // safety timeout in case the processor never reaches the halt loop
    initial begin
        #2000;
        $display("FAILED: simulation timed out without reaching halt loop");
        $stop;
    end

    // task to check the final register file contents against the
    // expected results computed from the reference program model
    task check_registers;
        begin
            check_reg(2, 32'd23);
            check_reg(3, 32'd12);
            check_reg(4, 32'd0);
            check_reg(5, 32'd11);
            check_reg(6, 32'd2);
            check_reg(7, 32'd6);
            check_reg(9, 32'd17);
        end
    endtask

    task check_reg(input integer idx, input logic [31:0] expected);
        logic [31:0] actual;
        begin
            actual = dut.rvsingle.dp.rf.rf[idx];
            if (actual === expected)
                $display("Register check PASSED: x%0d = %0d", idx, actual);
            else begin
                $display("Register check FAILED: x%0d = %0d (expected %0d)",
                          idx, actual, expected);
                $stop;
            end
        end
    endtask

endmodule
