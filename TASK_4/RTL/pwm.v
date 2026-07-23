// =============================================================================
// pwm_ip - Single-Channel PWM IP for VSDSquadron RISC-V SoC
// -----------------------------------------------------------------------------
// Memory-mapped, 32-bit registers, word-aligned.
//
// Base: PWM_BASE (assigned in SOC integration, e.g., 0x30000000)
// -----------------------------------------------------------------------------
//  Offset | Name   | R/W | Description
//  0x00   | CTRL   | R/W | Enable and polarity
//  0x04   | PERIOD | R/W | PWM period in clock ticks (>= 1)
//  0x08   | DUTY   | R/W | High time in clock ticks
//  0x0C   | STATUS | R   | Debug status  (bit0 = RUNNING, [31:16] = current cnt)
// -----------------------------------------------------------------------------
// CTRL bits:
//   bit 0 : EN  (1 = enable PWM output)
//   bit 1 : POL (0 = active-high, 1 = active-low)
// -----------------------------------------------------------------------------
// PWM output rule:
//   Let cnt run 0..PERIOD-1.
//     pwm_raw = (cnt < DUTY)
//     pwm_out = POL ? ~pwm_raw : pwm_raw
//   When EN = 0, pwm_out is forced to the inactive level (POL selects level).
// =============================================================================
module pwm_ip (
    input  wire        clk,
    input  wire        reset,     // synchronous, active-high
    input  wire        valid,     // bus transaction valid (chip-select)
    input  wire [31:0] addr,      // byte address (only addr[3:0] decoded here)
    input  wire [31:0] wdata,
    input  wire [3:0]  wmask,     // per-byte write mask (0 => read)
    output reg  [31:0] rdata,
    output wire        pwm_out    // PWM output to LED / GPIO / pin
);

    // -----------------------------------------------------------------
    // Register storage
    // -----------------------------------------------------------------
    reg [31:0] ctrl_reg;
    reg [31:0] period_reg;
    reg [31:0] duty_reg;
    reg [31:0] counter;

    wire en   = ctrl_reg[0];
    wire pol  = ctrl_reg[1];

    // -----------------------------------------------------------------
    // Register write logic (byte-strobed)
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            ctrl_reg   <= 32'h0;
            period_reg <= 32'd1;       // safe default: period = 1
            duty_reg   <= 32'h0;
        end else if (valid && (wmask != 4'b0000)) begin
            case (addr[3:0])
                4'h0: begin // CTRL
                    if (wmask[0]) ctrl_reg[ 7: 0] <= wdata[ 7: 0];
                    if (wmask[1]) ctrl_reg[15: 8] <= wdata[15: 8];
                    if (wmask[2]) ctrl_reg[23:16] <= wdata[23:16];
                    if (wmask[3]) ctrl_reg[31:24] <= wdata[31:24];
                end
                4'h4: begin // PERIOD
                    if (wmask[0]) period_reg[ 7: 0] <= wdata[ 7: 0];
                    if (wmask[1]) period_reg[15: 8] <= wdata[15: 8];
                    if (wmask[2]) period_reg[23:16] <= wdata[23:16];
                    if (wmask[3]) period_reg[31:24] <= wdata[31:24];
                end
                4'h8: begin // DUTY
                    if (wmask[0]) duty_reg[ 7: 0] <= wdata[ 7: 0];
                    if (wmask[1]) duty_reg[15: 8] <= wdata[15: 8];
                    if (wmask[2]) duty_reg[23:16] <= wdata[23:16];
                    if (wmask[3]) duty_reg[31:24] <= wdata[31:24];
                end
                default: ; // undefined offsets: writes ignored
            endcase
        end
    end

    // -----------------------------------------------------------------
    // Free-running counter (0 .. PERIOD-1) while enabled
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            counter <= 32'h0;
        end else if (!en) begin
            counter <= 32'h0;
        end else if (period_reg == 32'd0) begin
            counter <= 32'h0;
        end else if (counter >= (period_reg - 32'd1)) begin
            counter <= 32'h0;
        end else begin
            counter <= counter + 32'd1;
        end
    end

    // -----------------------------------------------------------------
    // PWM output generation
    //   DUTY = 0            => always low  (inactive)
    //   DUTY >= PERIOD      => always high (fully active)
    //   otherwise           => high while counter < DUTY
    //   EN = 0              => forced to inactive level (POL-selected)
    // -----------------------------------------------------------------
    wire pwm_raw = (counter < duty_reg);
    wire pwm_active_level = pol ? ~pwm_raw : pwm_raw;
    wire pwm_inactive     = pol ? 1'b1     : 1'b0;

    assign pwm_out = en ? pwm_active_level : pwm_inactive;

    // -----------------------------------------------------------------
    // Read logic (combinational)
    // -----------------------------------------------------------------
    always @(*) begin
        case (addr[3:0])
            4'h0: rdata = {30'b0, pol, en};                 // CTRL
            4'h4: rdata = period_reg;                       // PERIOD
            4'h8: rdata = duty_reg;                         // DUTY
            4'hC: rdata = {counter[15:0], 15'b0, en};       // STATUS (debug)
            default: rdata = 32'h0;
        endcase
    end

endmodule
