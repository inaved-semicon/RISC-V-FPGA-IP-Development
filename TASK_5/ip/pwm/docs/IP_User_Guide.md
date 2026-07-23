# PWM IP - User Guide

**Version:** 1.0
**Author:** VSDSquadron RISC-V IP Development Program
**Target Platform:** VSDSquadron FPGA Mini (Lattice iCE40UP5K)
**Bus:** 32-bit memory-mapped, word-aligned
**License:** Open (educational / prototype use)

---

## 1. IP Overview

The **PWM IP** is a single-channel, register-programmable Pulse Width Modulation generator designed for the VSDSquadron RISC-V SoC. It converts two register values (period and duty) into a digital PWM waveform on a dedicated output pin.

**Typical use cases**
- LED dimming and brightness control (visual demos, indicators, backlights)
- Servo motor angle control (adjust duty to set servo position)
- Simple DAC-like average-voltage output through a low-pass filter
- Fan-speed control and other digitally paced actuators

**Why use it**
- Zero-CPU-overhead waveform generation: once configured, the IP runs autonomously.
- Fully bus-controllable at runtime — duty can be updated on the fly without glitches.
- Small footprint (< 1300 LUTs contribution) on the iCE40UP5K.

---

## 2. Feature Summary

| Feature                           | Value / Support          |
|-----------------------------------|--------------------------|
| Channels                          | 1                        |
| Register bit-width                | 32                       |
| Bus interface                     | 32-bit memory-mapped, word-aligned |
| Reset                             | Synchronous, active-high |
| Modes                             | Single mode (edge-aligned PWM) |
| Polarity                          | Configurable active-high / active-low |
| Duty update behavior              | Live (takes effect on next counter wrap) |
| Frequency range (at 12 MHz clock) | ~183 Hz (PERIOD=65535) up to 6 MHz (PERIOD=2) |
| Interrupts                        | ❌ Not supported (poll STATUS) |
| Multiple channels                 | ❌ Single-channel only    |
| Fractional / center-aligned PWM   | ❌ Edge-aligned only      |

**Limitations (by design)**
- No interrupt line — software must poll `STATUS` if it needs a period marker.
- No dead-time / complementary output (single-ended output only).
- No hardware synchronization between multiple PWM instances.

---

## 3. Block Diagram

```
        ┌────────────────────────────────────────┐
        │                 pwm_ip                 │
        │                                        │
CPU Bus ─┤ addr / wdata / wmask / valid          │
        │   │                                    │
        │   ▼                                    │
        │  Register Decode                       │
        │   │      │        │                    │
        │   ▼      ▼        ▼                    │
        │  CTRL  PERIOD   DUTY   (STATUS ro)     │
        │   │      │        │                    │
        │   └──────┴────┬───┘                    │
        │               ▼                        │
        │       Free-running Counter             │
        │        (0 .. PERIOD-1, sync reset)     │
        │               │                        │
        │               ▼                        │
        │    Compare (counter < DUTY)            │
        │               │                        │
        │               ▼                        │
        │      Polarity + EN Mux ── pwm_out ────►│
        │                                        │
        └────────────────────────────────────────┘
```

---

## 4. Register Map (summary)

Base address is assigned during SoC integration. In the reference VSDSquadron SoC, the base is `0x30000000`.

| Offset | Register | Access | Reset      | Description                    |
|--------|----------|--------|------------|--------------------------------|
| 0x00   | CTRL     | R/W    | 0x00000000 | Enable and polarity            |
| 0x04   | PERIOD   | R/W    | 0x00000001 | PWM period in clock ticks      |
| 0x08   | DUTY     | R/W    | 0x00000000 | High time in clock ticks       |
| 0x0C   | STATUS   | R      | -          | Debug status (running, counter)|

See [Register_Map.md](Register_Map.md) for full bit-level definitions.

---

## 5. Software Programming Model

The PWM IP is programmed as a simple sequence of memory-mapped writes.

**Typical initialization sequence**

1. Write `PERIOD` (must be ≥ 1). This defines the PWM frequency:
   `f_pwm = f_clk / PERIOD`
2. Write `DUTY` (0 … PERIOD). This defines the on-time.
3. Write `CTRL = 0x1` to enable the output (POL = 0, active-high).

**Runtime control**
- To change brightness / duty ratio, simply write a new value to `DUTY`. The change takes effect from the next counter wrap (edge-aligned, glitch-free).
- To stop the output, write `CTRL = 0x0`. `pwm_out` returns to the polarity-selected inactive level.
- To read live status (running flag, current counter for debug), read `STATUS`.

**Polling model** — no interrupts are used; software drives the IP purely by writes.

---

## 6. Integration Guide (Very Important)

Answered in full in [Integration_Guide.md](Integration_Guide.md).

Quick summary:

- Required RTL file: [`rtl/pwm.v`](../rtl/pwm.v)
- Instantiate `pwm_ip` in your SoC top module.
- Decode a 4 KB (or larger) address window and gate `valid` and `wmask`.
- Expose the module's `pwm_out` output on a top-level pin.

---

## 7. Board-Level Usage (VSDSquadron FPGA Mini)

The reference SoC in `TASK_4` routes `pwm_out` onto **LEDS[0]** (Pin 39) via a mux inside the SoC, so no external wiring is required to see the LED-fade demo.

Alternative pin choices (edit `VSDSquadronFM.pcf` in the SoC to add a top-level `PWM_OUT` port if you want a header pin):

| Signal    | FPGA Pin | Comment                                              |
|-----------|----------|------------------------------------------------------|
| LEDS[0]   | 39       | On-board LED (default demo target — recommended)     |
| Header IO | 27       | External LED / scope / servo signal                  |

---

## 8. Example Software (Mandatory)

A complete, ready-to-run C example is provided in [`software/pwm_test.c`](../software/pwm_test.c). It:

- Sets `PERIOD = 1024` (≈ 11.7 kHz at 12 MHz)
- Enables the PWM
- Sweeps `DUTY` from `0` to `PERIOD` and back to produce a fade effect

See [Example_Usage.md](Example_Usage.md) for a walk-through and additional examples (fixed brightness, servo pulse).

---

## 9. Validation & Expected Output

**Simulation (Icarus Verilog):**
- Program `PERIOD = 10, DUTY = 3` → `pwm_out` is high for 3/10 cycles.
- Update `DUTY = 7` at runtime → `pwm_out` is high for 7/10 cycles.
- Set `POL = 1` → output inverts.
- Set `EN = 0` → output is forced to the inactive level.

Expected simulation prints (from [`test/pwm_tb.v`](../test/pwm_tb.v)):

```
PASS: Duty ratio verified (3/10 = 30%).
PASS: Duty update verified (7/10 = 70%).
PASS: Polarity inversion verified.
PASS: EN=0 with POL=1 forces output high (inactive).
PASS: EN=0 with POL=0 forces output low (inactive).
```

**Hardware (VSDSquadron FPGA Mini):**
- `LED0` fades smoothly up and down.
- Terminal (9600 baud) prints:

```
Task 4 - PWM IP Test
PWM_BASE = 0x30000000
Configured: PERIOD=1024 DUTY=0 CTRL=0x1
Fading LED0 up and down. Watch the on-board LED.
```

**Common failure symptoms**

| Symptom                                 | Likely Cause                                                       |
|-----------------------------------------|--------------------------------------------------------------------|
| LED0 does not fade (stays off)          | `CTRL.EN` never set, or firmware never programmed `PERIOD` / `DUTY`|
| LED0 stays fully on                     | `DUTY ≥ PERIOD`, or `POL = 1` selected with intended active-high   |
| LED0 flickers visibly                   | `PERIOD` too large (frequency below ~100 Hz) — reduce PERIOD       |
| No UART output                          | UART wiring or baud mismatch — see TASK_2/3 hardware setup         |
| Bitstream too big / synthesis fails     | Missing `pwm.v` in file list; ensure `` `include "pwm.v"` ``       |

---

## 10. Known Limitations & Notes

- **Single-channel only.** Instantiate multiple `pwm_ip` blocks for more channels.
- **No interrupt output.** Software must poll `STATUS`.
- **Assumes system clock of 12 MHz** (VSDSquadron FPGA Mini default). Formulas in this doc use 12 MHz; recompute for other clocks: `f_pwm = f_clk / PERIOD`.
- **Duty is not double-buffered** in a strict sense, but it is aligned to the counter wrap: writes appear on the next period boundary, avoiding glitches.
- **`PERIOD = 0` is treated as a safe zero:** the counter is held at 0 and `pwm_out` is inactive. Always program `PERIOD ≥ 1`.
- **Reads from undefined offsets return 0. Writes to undefined offsets are ignored.**
