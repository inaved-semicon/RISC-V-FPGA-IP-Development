# PWM IP - Integration Guide

This document explains, step by step, how to plug the PWM IP into a VSDSquadron RISC-V SoC (or any similar 32-bit memory-mapped bus).

Assume the reader is familiar with the VSDSquadron FPGA Mini toolchain (Yosys + nextpnr-ice40 + icestorm) but has not read the PWM IP source.

---

## 1. Files You Need

Copy the following into your project (or reference them directly from this repository):

| File                          | Purpose                                    |
|-------------------------------|--------------------------------------------|
| [`rtl/pwm.v`](../rtl/pwm.v)   | The PWM IP RTL (module `pwm_ip`).          |
| [`software/pwm_test.c`](../software/pwm_test.c) | Reference C driver / demo.        |
| [`test/pwm_tb.v`](../test/pwm_tb.v) | Testbench for local simulation.          |

No other RTL dependencies. `pwm_ip` uses only standard Verilog-2005 constructs — synthesizable with Yosys.

---

## 2. Module Interface

```verilog
module pwm_ip (
    input  wire        clk,      // system clock (e.g., 12 MHz)
    input  wire        reset,    // synchronous, active-high
    input  wire        valid,    // chip-select (address in PWM window AND rstrb|wstrb)
    input  wire [31:0] addr,     // full byte address (only addr[3:0] decoded)
    input  wire [31:0] wdata,    // write data
    input  wire [3:0]  wmask,    // per-byte write enable (0 => read)
    output reg  [31:0] rdata,    // read data (combinational)
    output wire        pwm_out   // PWM output to LED / GPIO / header pin
);
```

Signal notes:
- `valid` must be asserted for exactly one cycle per bus transaction, indicating the address falls in the PWM window.
- `wmask == 4'b0000` means the transaction is a read (no register update).
- `rdata` is a combinational function of `addr[3:0]` and the internal state.

---

## 3. Where to Instantiate

Instantiate `pwm_ip` at the same level where you connect RAM and other memory-mapped peripherals (typically the SoC top module).

Reference instantiation from `TASK_4/RTL/riscv.v`:

```verilog
`include "pwm.v"

// --- Address decode ---
// Reserve the address window whose top nibble is 0x3 (0x30000000 .. 0x3FFFFFFF)
wire isPWM = (mem_addr[31:28] == 4'h3);

// Combined valid: high when the CPU is doing any access into the PWM window
wire        pwm_valid = isPWM && (mem_rstrb | (|mem_wmask));
wire [31:0] pwm_rdata;
wire        pwm_out;

pwm_ip my_pwm (
    .clk    (clk),
    .reset  (!resetn),          // Clockworks provides active-low resetn
    .valid  (pwm_valid),
    .addr   (mem_addr),
    .wdata  (mem_wdata),
    .wmask  ({4{isPWM}} & mem_wmask), // mask off writes when not selected
    .rdata  (pwm_rdata),
    .pwm_out(pwm_out)
);

// Read-data mux
assign mem_rdata = isPWM ? pwm_rdata :
                   isRAM ? RAM_rdata :
                           IO_rdata;
```

---

## 4. Address Decoding Expectations

- Reserve at least a 4 KB address window aligned on 4 KB. Reference: `0x30000000 .. 0x30000FFF`.
- Match on the top nibble (or as many bits as your address map requires) to build `isPWM`.
- **Prevent** other peripherals (RAM, GPIO, IO page) from responding when `isPWM = 1` — this is typically done via a mutually-exclusive read-data mux and gated write masks (see reference above).

---

## 5. Signals Exposed to Top-Level

Only one signal must be exposed to the top-level of the SoC:

| Signal    | Direction | Description                              |
|-----------|-----------|------------------------------------------|
| `pwm_out` | output    | PWM waveform; connect to an FPGA pin.    |

Two integration styles are supported:

### Style A - Mux onto an existing LED (used by TASK_4 reference)

```verilog
// LEDS[0] shows PWM output; LEDS[4:1] remain fully software-controlled.
assign LEDS = {leds_reg[4:1], pwm_out | leds_reg[0]};
```

- No extra PCF entry needed — reuses the LED pin.

### Style B - Dedicated top-level output pin

```verilog
module SOC (
    input  wire        RESET,
    output wire [4:0]  LEDS,
    output wire        PWM_OUT,   // new
    output wire        TXD,
    input  wire        RXD
);
    ...
    assign PWM_OUT = pwm_out;
```

Add a matching entry to your `.pcf`:

```
set_io PWM_OUT 27
```

---

## 6. Pin Connections (VSDSquadron FPGA Mini)

Reference PCF used by `TASK_4/RTL/VSDSquadronFM.pcf` (Style A — no PCF changes needed):

```
set_io LEDS[0] 39   # PWM output visible here
set_io LEDS[1] 41
set_io LEDS[2] 40
set_io LEDS[3] 25
set_io LEDS[4] 26

set_io RESET  23
set_io TXD    4
set_io RXD    3
```

For Style B, choose any free header IO (e.g., pin 27) and add `set_io PWM_OUT <pin>`.

---

## 7. Reset & Clock

- `clk` is the system clock. The reference SoC uses **12 MHz** from `SB_HFOSC`. The IP is fully synchronous and has no clock-crossing.
- `reset` is **synchronous and active-high**. In the reference SoC, the Clockworks module produces an active-low `resetn`, which is inverted before being fed to `pwm_ip.reset`.

---

## 8. Constraint / Timing

No special timing constraints are required beyond the SoC-wide clock constraint. `pwm_ip` runs comfortably above 50 MHz on iCE40UP5K in the reference build.

---

## 9. Post-Integration Checklist

- [ ] `` `include "pwm.v"` `` (or add `pwm.v` to your project file list).
- [ ] `isPWM` decode covers your chosen 4 KB window and does **not** overlap other peripherals.
- [ ] Read-data mux returns `pwm_rdata` when `isPWM = 1`.
- [ ] `wmask` is gated by `isPWM` (do not disturb other peripherals).
- [ ] `pwm_out` is either muxed onto an LED (Style A) or exposed as a dedicated top-level output (Style B) with a matching PCF entry.
- [ ] Firmware defines `#define PWM_BASE 0x30000000` (or your chosen base) and uses the offsets from [Register_Map.md](Register_Map.md).
