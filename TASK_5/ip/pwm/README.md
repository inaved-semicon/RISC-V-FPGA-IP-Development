# PWM IP (Commercial-Grade Release)

A single-channel, register-programmable **Pulse Width Modulation** peripheral for the VSDSquadron RISC-V SoC on the VSDSquadron FPGA Mini (Lattice iCE40UP5K).

This directory is the **plug-and-play IP release** produced for Task-5 of the VSDSquadron FPGA Mini IP development program. It is intended to be dropped into any VSDSquadron-style RISC-V SoC and used without reading the RTL.

---

## What This IP Is

- **1× PWM output**, edge-aligned, register-programmable period and duty.
- **32-bit memory-mapped** register interface (CTRL, PERIOD, DUTY, STATUS).
- Configurable **polarity** (active-high / active-low) and **enable**.
- Fully **synchronous** design, single clock domain.
- Fits comfortably on iCE40UP5K (reference SoC uses ~1300 LUTs total).

Typical use cases: LED dimming, servo control, simple average-voltage DAC via low-pass filter, fan-speed control.

---

## How to Integrate It (30-second version)

1. Copy [`rtl/pwm.v`](rtl/pwm.v) into your project.
2. In your SoC top module, add ``` `include "pwm.v" ``` and instantiate `pwm_ip`.
3. Reserve a 4 KB address window (recommended base: `0x30000000`) and wire it up:
   ```verilog
   wire isPWM = (mem_addr[31:28] == 4'h3);
   wire pwm_valid = isPWM && (mem_rstrb | (|mem_wmask));

   pwm_ip u_pwm (
       .clk(clk), .reset(!resetn),
       .valid(pwm_valid),
       .addr(mem_addr), .wdata(mem_wdata),
       .wmask({4{isPWM}} & mem_wmask),
       .rdata(pwm_rdata),
       .pwm_out(pwm_out)
   );

   assign mem_rdata = isPWM ? pwm_rdata : /* other peripherals */ ;
   ```
4. Route `pwm_out` to an FPGA pin (an on-board LED or a header). The reference SoC muxes it onto **LEDS[0]**.
5. From C, write PERIOD, DUTY, and `CTRL = 1`. Done.

Full step-by-step instructions in [`docs/Integration_Guide.md`](docs/Integration_Guide.md).

---

## Where to Find the Docs

| Document                                        | Purpose                                                        |
|-------------------------------------------------|----------------------------------------------------------------|
| [`docs/IP_User_Guide.md`](docs/IP_User_Guide.md)         | Overview, block diagram, programming model, limitations.       |
| [`docs/Register_Map.md`](docs/Register_Map.md)           | Bit-accurate register/field definitions, reset values.         |
| [`docs/Integration_Guide.md`](docs/Integration_Guide.md) | Files required, instantiation template, pin mapping, checklist.|
| [`docs/Example_Usage.md`](docs/Example_Usage.md)         | Four ready-to-adapt firmware examples (fade, fixed, UART, servo).|

---

## How to Test It

**Simulation (Icarus Verilog):**

```bash
cd test
iverilog -o pwm_tb pwm_tb.v -I ../rtl
vvp pwm_tb
```

Expected output:

```
PASS: Duty ratio verified (3/10 = 30%).
PASS: Duty update verified (7/10 = 70%).
PASS: Polarity inversion verified.
PASS: EN=0 with POL=1 forces output high (inactive).
PASS: EN=0 with POL=0 forces output low (inactive).
```

**Hardware (VSDSquadron FPGA Mini):**

Follow the reference build in `TASK_4/` (`Firmware/` → `RTL/`):

```bash
cd TASK_4/Firmware
make clean
make pwm_test.bram.hex
cd ../RTL
make build && make flash && make terminal
```

`LED0` on the board fades up and down. UART prints:

```
Task 4 - PWM IP Test
PWM_BASE = 0x30000000
Configured: PERIOD=1024 DUTY=0 CTRL=0x1
Fading LED0 up and down. Watch the on-board LED.
```

---

## Directory Layout

```
ip/pwm/
├── rtl/
│   └── pwm.v                # Synthesizable Verilog for pwm_ip
├── software/
│   └── pwm_test.c           # Reference driver / demo firmware
├── test/
│   └── pwm_tb.v             # Icarus-Verilog testbench
├── docs/
│   ├── IP_User_Guide.md
│   ├── Register_Map.md
│   ├── Integration_Guide.md
│   └── Example_Usage.md
└── README.md                # (this file)
```

---

## Register Map (Quick Reference)

Base address in the reference SoC: **`0x30000000`**.

| Offset | Name    | R/W | Reset       | Description                        |
|--------|---------|-----|-------------|------------------------------------|
| 0x00   | CTRL    | R/W | 0x00000000  | `bit0` EN, `bit1` POL              |
| 0x04   | PERIOD  | R/W | 0x00000001  | PWM period (ticks)                 |
| 0x08   | DUTY    | R/W | 0x00000000  | PWM high-time (ticks)              |
| 0x0C   | STATUS  | R   | -           | `[31:16]` counter, `[0]` RUNNING   |

See [`docs/Register_Map.md`](docs/Register_Map.md) for full bit definitions.

---

## Features & Limitations

**Supported**
- 32-bit programmable PERIOD and DUTY
- Active-high / active-low polarity (`CTRL.POL`)
- Runtime duty update (edge-aligned, glitch-free)
- Optional debug STATUS register

**Not supported (by design)**
- Interrupts (poll STATUS if needed)
- Multiple channels per instance (instantiate multiple `pwm_ip` blocks)
- Center-aligned or fractional PWM
- Dead-time or complementary output

---

## License / Attribution

Released for VSDSquadron educational and prototype use. The RTL builds on the SoC scaffolding from the VSDSquadron RISC-V FPGA IP development program (TASK_1–TASK_3) and is designed to integrate cleanly with that SoC template.
