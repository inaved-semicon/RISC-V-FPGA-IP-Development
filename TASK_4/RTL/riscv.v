/**
 * TASK_4: RISC-V SoC with GPIO IP (from TASK_3) and PWM IP (new)
 *
 * Memory Map:
 *   0x00000000  RAM      (6 KB, in Memory module)
 *   0x00400000  IO page  (LEDs, UART) - uses bit 22 as select
 *   0x20000000  GPIO IP  (kept from TASK_3, but not instantiated here to keep
 *                        PWM as the sole custom IP for this task's demo)
 *   0x30000000  PWM IP   (this task)
 */

`default_nettype none
`include "clockworks.v"
`include "emitter_uart.v"
`include "pwm.v"

module Memory (
   input             clk,
   input      [31:0] mem_addr,
   output reg [31:0] mem_rdata,
   input             mem_rstrb,
   input      [31:0] mem_wdata,
   input      [3:0]  mem_wmask
);

   reg [31:0] MEM [0:1535]; // 6 KB

   initial begin
       $readmemh("firmware.hex", MEM);
   end

   wire [29:0] word_addr = mem_addr[31:2];

   always @(posedge clk) begin
      if (mem_rstrb) begin
         mem_rdata <= MEM[word_addr];
      end
      if (mem_wmask[0]) MEM[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
      if (mem_wmask[1]) MEM[word_addr][15: 8] <= mem_wdata[15: 8];
      if (mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
      if (mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];
   end
endmodule


module Processor (
    input         clk,
    input         resetn,
    output [31:0] mem_addr,
    input  [31:0] mem_rdata,
    output        mem_rstrb,
    output [31:0] mem_wdata,
    output [3:0]  mem_wmask
);

   reg [31:0] PC = 0;
   reg [31:0] instr;

   wire isALUreg  =  (instr[6:0] == 7'b0110011);
   wire isALUimm  =  (instr[6:0] == 7'b0010011);
   wire isBranch  =  (instr[6:0] == 7'b1100011);
   wire isJALR    =  (instr[6:0] == 7'b1100111);
   wire isJAL     =  (instr[6:0] == 7'b1101111);
   wire isAUIPC   =  (instr[6:0] == 7'b0010111);
   wire isLUI     =  (instr[6:0] == 7'b0110111);
   wire isLoad    =  (instr[6:0] == 7'b0000011);
   wire isStore   =  (instr[6:0] == 7'b0100011);
   wire isSYSTEM  =  (instr[6:0] == 7'b1110011);

   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

   wire [4:0] rs1Id = instr[19:15];
   wire [4:0] rs2Id = instr[24:20];
   wire [4:0] rdId  = instr[11:7];
   wire [2:0] funct3 = instr[14:12];
   wire [6:0] funct7 = instr[31:25];

   reg  [31:0] RegisterBank [0:31];
   reg  [31:0] rs1;
   reg  [31:0] rs2;
   wire [31:0] writeBackData;
   wire        writeBackEn;

`ifdef BENCH
   integer i;
   initial begin
      for (i = 0; i < 32; i = i + 1) RegisterBank[i] = 0;
   end
`endif

   wire [31:0] aluIn1 = rs1;
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;
   wire [4:0]  shamt  = isALUreg ? rs2[4:0] : instr[24:20];

   wire [31:0] aluPlus  = aluIn1 + aluIn2;
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0, aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
                x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
                x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
                x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

   wire [31:0] shifter_in = (funct3 == 3'b001) ? flip32(aluIn1) : aluIn1;
   /* verilator lint_off WIDTH */
   wire [31:0] shifter =
               $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
   /* verilator lint_on WIDTH */
   wire [31:0] leftshift = flip32(shifter);

   reg [31:0] aluOut;
   always @(*) begin
      case (funct3)
        3'b000: aluOut = (funct7[5] & instr[5]) ? aluMinus[31:0] : aluPlus;
        3'b001: aluOut = leftshift;
        3'b010: aluOut = {31'b0, LT};
        3'b011: aluOut = {31'b0, LTU};
        3'b100: aluOut = (aluIn1 ^ aluIn2);
        3'b101: aluOut = shifter;
        3'b110: aluOut = (aluIn1 | aluIn2);
        3'b111: aluOut = (aluIn1 & aluIn2);
      endcase
   end

   reg takeBranch;
   always @(*) begin
      case (funct3)
        3'b000: takeBranch =  EQ;
        3'b001: takeBranch = !EQ;
        3'b100: takeBranch =  LT;
        3'b101: takeBranch = !LT;
        3'b110: takeBranch =  LTU;
        3'b111: takeBranch = !LTU;
        default: takeBranch = 1'b0;
      endcase
   end

   wire [31:0] PCplusImm = PC + ( instr[3] ? Jimm[31:0] :
                                  instr[4] ? Uimm[31:0] :
                                             Bimm[31:0] );
   wire [31:0] PCplus4 = PC + 4;

   assign writeBackData = (isJAL || isJALR) ? PCplus4   :
                              isLUI         ? Uimm      :
                              isAUIPC       ? PCplusImm :
                              isLoad        ? LOAD_data :
                                              aluOut;

   wire [31:0] nextPC = ((isBranch && takeBranch) || isJAL) ? PCplusImm      :
                                          isJALR   ? {aluPlus[31:1], 1'b0}   :
                                                      PCplus4;

   wire [31:0] loadstore_addr = rs1 + (isStore ? Simm : Iimm);

   wire        mem_byteAccess     = funct3[1:0] == 2'b00;
   wire        mem_halfwordAccess = funct3[1:0] == 2'b01;

   wire [15:0] LOAD_halfword =
               loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];
   wire [ 7:0] LOAD_byte =
               loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   wire LOAD_sign =
        !funct3[2] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess     ? {{24{LOAD_sign}},     LOAD_byte} :
         mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                              mem_rdata;

   assign mem_wdata[ 7: 0] = rs2[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[ 7:0] : rs2[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[ 7:0] : rs2[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[ 7:0] :
                             loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   wire [3:0] STORE_wmask =
              mem_byteAccess ?
                    (loadstore_addr[1] ?
                          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
                          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
              mem_halfwordAccess ?
                    (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   localparam FETCH_INSTR = 0;
   localparam WAIT_INSTR  = 1;
   localparam FETCH_REGS  = 2;
   localparam EXECUTE     = 3;
   localparam LOAD        = 4;
   localparam WAIT_DATA   = 5;
   localparam STORE       = 6;
   reg [2:0] state = FETCH_INSTR;

   always @(posedge clk) begin
      if (!resetn) begin
         PC    <= 0;
         state <= FETCH_INSTR;
      end else begin
         if (writeBackEn && rdId != 0) begin
            RegisterBank[rdId] <= writeBackData;
         end
         case (state)
           FETCH_INSTR: state <= WAIT_INSTR;
           WAIT_INSTR:  begin instr <= mem_rdata; state <= FETCH_REGS; end
           FETCH_REGS:  begin rs1   <= RegisterBank[rs1Id];
                              rs2   <= RegisterBank[rs2Id];
                              state <= EXECUTE; end
           EXECUTE:  begin
              if (!isSYSTEM) PC <= nextPC;
              state <= isLoad  ? LOAD  :
                       isStore ? STORE :
                                 FETCH_INSTR;
`ifdef BENCH
              if (isSYSTEM) $finish();
`endif
           end
           LOAD:      state <= WAIT_DATA;
           WAIT_DATA: state <= FETCH_INSTR;
           STORE:     state <= FETCH_INSTR;
         endcase
      end
   end

   assign writeBackEn = (state == EXECUTE && !isBranch && !isStore) ||
                        (state == WAIT_DATA);

   assign mem_addr  = (state == WAIT_INSTR || state == FETCH_INSTR) ?
                      PC : loadstore_addr;
   assign mem_rstrb = (state == FETCH_INSTR || state == LOAD);
   assign mem_wmask = {4{(state == STORE)}} & STORE_wmask;

endmodule


module SOC (
    input  wire       RESET,
    output wire [4:0] LEDS,
    output wire       TXD,
    input  wire       RXD
);

   wire        clk;
   wire        clk_int;
   wire        resetn;

   wire [31:0] mem_addr;
   wire [31:0] mem_rdata;
   wire        mem_rstrb;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;

   Processor CPU (
      .clk     (clk),
      .resetn  (resetn),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask)
   );

   wire [31:0] RAM_rdata;
   wire [29:0] mem_wordaddr = mem_addr[31:2];

   // --- Address Decoding ---
   //   0x0000_0000 .. RAM
   //   0x0040_0000  IO page (bit 22 set)
   //   0x3000_0000  PWM  (top nibble = 0x3)
   wire isPWM = (mem_addr[31:28] == 4'h3);
   wire isIO  = mem_addr[22];
   wire isRAM = !isIO && !isPWM;

   wire mem_wstrb = |mem_wmask;

   Memory RAM (
      .clk      (clk),
      .mem_addr (mem_addr),
      .mem_rdata(RAM_rdata),
      .mem_rstrb(isRAM & mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask({4{isRAM}} & mem_wmask)
   );

   // --- PWM IP Integration ---
   wire        pwm_valid = isPWM && (mem_rstrb | mem_wstrb);
   wire [31:0] pwm_rdata;
   wire        pwm_out;

   pwm_ip my_pwm_block (
      .clk    (clk),
      .reset  (!resetn),
      .valid  (pwm_valid),
      .addr   (mem_addr),
      .wdata  (mem_wdata),
      .wmask  ({4{isPWM}} & mem_wmask),
      .rdata  (pwm_rdata),
      .pwm_out(pwm_out)
   );

   // --- IO page: LEDs + UART ---
   localparam IO_LEDS_bit      = 0;  // W  five leds
   localparam IO_UART_DAT_bit  = 1;  // W  UART data
   localparam IO_UART_CNTL_bit = 2;  // R  UART status

   reg [4:0] leds_reg;

   always @(posedge clk) begin
      if (!resetn) begin
         leds_reg <= 5'b0;
      end else if (isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit]) begin
         leds_reg <= mem_wdata[4:0];
      end
   end

   // pwm_out is muxed onto LEDS[0] when PWM is enabled (bit0 of pwm_rdata's CTRL
   // read = EN). We derive EN by reading the PWM IP's CTRL register status.
   // To keep it purely combinational, we let pwm_out itself carry the level:
   //  - when PWM.EN = 0  =>  pwm_out is forced inactive by the IP itself; user
   //    can regain LED0 by writing to leds_reg (it will just be overridden by
   //    pwm_out's inactive level). This is the documented board-demo behavior.
   assign LEDS = {leds_reg[4:1], pwm_out | leds_reg[0]};

   wire        uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];
   wire        uart_ready;

   corescore_emitter_uart #(
      .clk_freq_hz(12*1000000),
      .baud_rate  (9600)
   ) UART (
      .i_clk   (clk),
      .i_rst   (!resetn),
      .i_data  (mem_wdata[7:0]),
      .i_valid (uart_valid),
      .o_ready (uart_ready),
      .o_uart_tx(TXD)
   );

   wire [31:0] IO_rdata =
          mem_wordaddr[IO_UART_CNTL_bit] ? {22'b0, !uart_ready, 9'b0}
                                         : 32'b0;

   // --- Read Data Mux ---
   assign mem_rdata = isPWM ? pwm_rdata :
                      isRAM ? RAM_rdata :
                              IO_rdata;

`ifdef BENCH
   always @(posedge clk) begin
      if (uart_valid) begin
         $write("%c", mem_wdata[7:0]);
         $fflush(32'h8000_0001);
      end
   end
`endif

   SB_HFOSC #(
      .CLKHF_DIV("0b10") // 12 MHz
   ) hfosc (
      .CLKHFPU(1'b1),
      .CLKHFEN(1'b1),
      .CLKHF  (clk_int)
   );

   Clockworks CW (
      .CLK   (clk_int),
      .RESET (RESET),
      .clk   (clk),
      .resetn(resetn)
   );

endmodule
