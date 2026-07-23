`timescale 1ns / 1ps
`include "gpio.v"
module gpio_tb;

    reg clk;
    reg reset;
    reg valid;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg [3:0] wmask;
    wire [31:0] rdata;
    
    wire [31:0] gpio_pin;

    gpio_ip uut (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .addr(addr),
        .wdata(wdata),
        .wmask(wmask),
        .rdata(rdata),
        .gpio_pin(gpio_pin)
    );

    // Simulate input signals from the outside world on the upper 16 pins
    assign gpio_pin[31:16] = 16'hAAAA; 

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("gpio_tb.vcd");
        $dumpvars(0, gpio_tb);

        reset = 1;
        valid = 0;
        addr  = 0;
        wdata = 0;
        wmask = 0;
        
        #20 reset = 0;

        // 1. Write to DIR Register (Offset 0x04)
        @(posedge clk);
        #1; 
        valid = 1;
        wmask = 4'b1111;
        addr  = 32'h20000004;
        wdata = 32'h0000FFFF;

        // 2. Write to DATA Register (Offset 0x00)
        @(posedge clk);
        #1;
        addr  = 32'h20000000;
        wdata = 32'h12345678;

        // 3. Read from READ Register (Offset 0x08)
        @(posedge clk);
        #1;
        wmask = 4'b0000;
        addr  = 32'h20000008;

        @(posedge clk);
        #1;
        valid = 0;
        
        #10;
        if (rdata == 32'hAAAA5678) begin
            $display("PASS: Readback verified! Value is %h", rdata);
        end else begin
            $display("FAIL: Expected AAAA5678, got %h", rdata);
        end

        #20 $finish;
    end
endmodule