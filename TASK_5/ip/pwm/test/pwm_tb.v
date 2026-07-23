`timescale 1ns / 1ps
`include "pwm.v"

// =============================================================================
// pwm_tb - Testbench for pwm_ip
//   * Programs PERIOD and DUTY through the memory-mapped bus interface
//   * Observes pwm_out waveform
//   * Verifies duty ratio in one full period
//   * Dumps VCD for GTKWave viewing (pwm_tb.vcd)
// =============================================================================
module pwm_tb;

    reg         clk;
    reg         reset;
    reg         valid;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    reg  [3:0]  wmask;
    wire [31:0] rdata;
    wire        pwm_out;

    // Design under test
    pwm_ip uut (
        .clk    (clk),
        .reset  (reset),
        .valid  (valid),
        .addr   (addr),
        .wdata  (wdata),
        .wmask  (wmask),
        .rdata  (rdata),
        .pwm_out(pwm_out)
    );

    // 100 MHz test clock (period = 10 ns)
    initial clk = 0;
    always #5 clk = ~clk;

    // Sample the PWM output every cycle to measure high time
    integer high_count;
    integer sample_count;

    // Bus write helper task
    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(posedge clk); #1;
            valid = 1;
            wmask = 4'b1111;
            addr  = a;
            wdata = d;
            @(posedge clk); #1;
            valid = 0;
            wmask = 4'b0000;
        end
    endtask

    initial begin
        $dumpfile("pwm_tb.vcd");
        $dumpvars(0, pwm_tb);

        // Init
        reset = 1;
        valid = 0;
        addr  = 0;
        wdata = 0;
        wmask = 0;
        high_count   = 0;
        sample_count = 0;

        #25 reset = 0;

        // Program PERIOD = 10, DUTY = 3 (30% duty), POL = 0, EN = 1
        bus_write(32'h30000004, 32'd10);   // PERIOD
        bus_write(32'h30000008, 32'd3);    // DUTY
        bus_write(32'h30000000, 32'h1);    // CTRL: EN=1, POL=0

        // Let PWM run 5 full periods and measure duty over one period after settle.
        // 5 periods = 50 cycles; sample 10 cycles = one full period.
        repeat (20) @(posedge clk);        // let counter settle

        // Sample the next full period (10 clock cycles)
        repeat (10) begin
            @(posedge clk); #1;
            sample_count = sample_count + 1;
            if (pwm_out) high_count = high_count + 1;
        end

        $display("Sampled %0d cycles, pwm_out was HIGH for %0d cycles (expected 3).",
                 sample_count, high_count);
        if (high_count == 3)
            $display("PASS: Duty ratio verified (3/10 = 30%%).");
        else
            $display("FAIL: Duty ratio incorrect. Got %0d, expected 3.", high_count);

        // Reprogram DUTY to 7 (70%) and briefly observe
        bus_write(32'h30000008, 32'd7);
        high_count   = 0;
        sample_count = 0;
        repeat (20) @(posedge clk);
        repeat (10) begin
            @(posedge clk); #1;
            sample_count = sample_count + 1;
            if (pwm_out) high_count = high_count + 1;
        end
        $display("After DUTY=7: high for %0d/10 cycles (expected 7).", high_count);
        if (high_count == 7)
            $display("PASS: Duty update verified (7/10 = 70%%).");
        else
            $display("FAIL: Duty update incorrect. Got %0d, expected 7.", high_count);

        // Test polarity inversion (POL = 1)
        bus_write(32'h30000000, 32'h3);    // EN=1, POL=1
        high_count   = 0;
        sample_count = 0;
        repeat (20) @(posedge clk);
        repeat (10) begin
            @(posedge clk); #1;
            sample_count = sample_count + 1;
            if (pwm_out) high_count = high_count + 1;
        end
        $display("With POL=1, DUTY=7: high for %0d/10 cycles (expected 3).", high_count);
        if (high_count == 3)
            $display("PASS: Polarity inversion verified.");
        else
            $display("FAIL: Polarity inversion incorrect. Got %0d, expected 3.", high_count);

        // Disable and check output goes to inactive level
        bus_write(32'h30000000, 32'h2);    // EN=0, POL=1 => inactive = 1
        @(posedge clk); #1;
        if (pwm_out === 1'b1)
            $display("PASS: EN=0 with POL=1 forces output high (inactive).");
        else
            $display("FAIL: EN=0 with POL=1 did not force output high, got %b.", pwm_out);

        bus_write(32'h30000000, 32'h0);    // EN=0, POL=0 => inactive = 0
        @(posedge clk); #1;
        if (pwm_out === 1'b0)
            $display("PASS: EN=0 with POL=0 forces output low (inactive).");
        else
            $display("FAIL: EN=0 with POL=0 did not force output low, got %b.", pwm_out);

        #50 $finish;
    end
endmodule
