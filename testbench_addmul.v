// Waveform testbench for the addmul RISC-V program
module testbench_addmul();
    logic clk;
    logic reset;
    logic [31:0] WriteData, DataAdr;
    logic MemWrite;

    // Instantiate the top-level design
    top dut (clk, reset, WriteData, DataAdr, MemWrite);

    // Clock generation: 10ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Reset pulse
    initial begin
        reset = 1'b1;
        #22;
        reset = 1'b0;
    end

    // Waveform dump
    initial begin
        $dumpfile("addmul.vcd");
        $dumpvars(0, dut);
    end

    // Run for a fixed number of cycles and stop
    integer cycle_count;
    initial begin
        cycle_count = 0;
        #30; // wait for reset deassertion
        while (cycle_count < 200) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        $display("Simulation stopped after %0d cycles", cycle_count);
        $finish;
    end
endmodule
