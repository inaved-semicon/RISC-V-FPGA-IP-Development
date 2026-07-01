module gpio_ip #(
    parameter [31:0] BASE_ADDR = 32'h2000_0000
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wmask,
    input  wire        wstrb,
    input  wire        rstrb,
    output reg  [31:0] rdata,
    output reg  [31:0] gpio_out
);

    wire sel = (addr == BASE_ADDR);

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_out <= 32'h00000000;
            rdata    <= 32'h00000000;
        end else begin
            if (sel && wstrb) begin
                if (wmask[0]) gpio_out[ 7: 0] <= wdata[ 7: 0];
                if (wmask[1]) gpio_out[15: 8] <= wdata[15: 8];
                if (wmask[2]) gpio_out[23:16] <= wdata[23:16];
                if (wmask[3]) gpio_out[31:24] <= wdata[31:24];
            end

            if (sel && rstrb) begin
                rdata <= gpio_out;
            end else if (!sel) begin
                rdata <= 32'h00000000;
            end
        end
    end
endmodule
