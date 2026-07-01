`timescale 1ns/1ps
`include "gpio.v"

module gpio_tb;
    reg        clk = 0;
    reg        resetn = 0;
    reg [31:0] addr = 32'h00000000;
    reg [31:0] wdata = 32'h00000000;
    reg [3:0]  wmask = 4'h0;
    reg        wstrb = 0;
    reg        rstrb = 0;
    wire [31:0] rdata;
    wire [31:0] gpio_out;

    gpio_ip #(.BASE_ADDR(32'h2000_0000)) dut (
        .clk(clk),
        .resetn(resetn),
        .addr(addr),
        .wdata(wdata),
        .wmask(wmask),
        .wstrb(wstrb),
        .rstrb(rstrb),
        .rdata(rdata),
        .gpio_out(gpio_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("gpio_tb.vcd");
        $dumpvars(0, gpio_tb);
    end

    initial begin
        #2 resetn = 0;
        #12 resetn = 1;

        // Full-word write and readback
        addr = 32'h2000_0000;
        wdata = 32'h11223344;
        wmask = 4'hf;
        wstrb = 1;
        rstrb = 0;
        #10;

        wstrb = 0;
        #10;

        rstrb = 1;
        #10;

        if (gpio_out !== 32'h11223344) begin
            $display("FAIL: gpio_out mismatch after full write: %h", gpio_out);
            $finish;
        end

        if (rdata !== 32'h11223344) begin
            $display("FAIL: rdata mismatch after full write: %h", rdata);
            $finish;
        end

        $display("PASS: full write/readback verified: %h", rdata);

        // Partial write using byte mask and readback
        wdata = 32'hA5A5A5A5;
        wmask = 4'b0011;
        wstrb = 1;
        rstrb = 0;
        #10;

        wstrb = 0;
        #10;

        rstrb = 1;
        #10;

        if (gpio_out !== 32'h1122A5A5) begin
            $display("FAIL: gpio_out mismatch after partial write: %h", gpio_out);
            $finish;
        end

        if (rdata !== 32'h1122A5A5) begin
            $display("FAIL: rdata mismatch after partial write: %h", rdata);
            $finish;
        end

        $display("PASS: partial write/readback verified: %h", rdata);
        $display("Waveform saved to gpio_tb.vcd");
        $finish;
    end
endmodule
