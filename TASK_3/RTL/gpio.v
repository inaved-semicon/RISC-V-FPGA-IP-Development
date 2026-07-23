module gpio_ip (
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wmask,
    output reg  [31:0] rdata,
    inout  wire [31:0] gpio_pin
);

    reg [31:0] gpio_data;
    reg [31:0] gpio_dir;
    wire [31:0] gpio_read;

    // Connect the physical pins
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : pin_logic
            assign gpio_pin[i] = gpio_dir[i] ? gpio_data[i] : 1'bz;
            // Read the data register if it is an output, otherwise read the pin
            assign gpio_read[i] = gpio_dir[i] ? gpio_data[i] : gpio_pin[i];
        end
    endgenerate

    // Write Logic
    always @(posedge clk) begin
        if (reset) begin
            gpio_data <= 32'h00000000;
            gpio_dir  <= 32'h00000000;
        end else if (valid) begin
            // Check offset 0x00 for DATA
            if (addr[3:0] == 4'h0 && wmask != 4'b0000) begin
                if (wmask[0]) gpio_data[7:0]   <= wdata[7:0];
                if (wmask[1]) gpio_data[15:8]  <= wdata[15:8];
                if (wmask[2]) gpio_data[23:16] <= wdata[23:16];
                if (wmask[3]) gpio_data[31:24] <= wdata[31:24];
            end
            // Check offset 0x04 for DIR
            else if (addr[3:0] == 4'h4 && wmask != 4'b0000) begin
                if (wmask[0]) gpio_dir[7:0]   <= wdata[7:0];
                if (wmask[1]) gpio_dir[15:8]  <= wdata[15:8];
                if (wmask[2]) gpio_dir[23:16] <= wdata[23:16];
                if (wmask[3]) gpio_dir[31:24] <= wdata[31:24];
            end
        end
    end

    // Read Logic (Always keep the data ready based on the address)
    always @(*) begin
        case (addr[3:0])
            4'h0: rdata = gpio_data;
            4'h4: rdata = gpio_dir;
            4'h8: rdata = gpio_read;
            default: rdata = 32'h00000000;
        endcase
    end

endmodule