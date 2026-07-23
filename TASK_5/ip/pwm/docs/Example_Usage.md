# PWM IP - Example Usage

This document walks through the reference driver in [`../software/pwm_test.c`](../software/pwm_test.c) and shows two additional example use cases: **fixed-brightness LED** and **servo-style pulse generation**.

All examples assume the SoC integration from `TASK_4` where:
- PWM base = `0x30000000`
- System clock = 12 MHz
- `pwm_out` is muxed onto **LED0** of the VSDSquadron FPGA Mini.

---

## 1. Register Header

All examples use the same lightweight header. You can copy this snippet into any firmware:

```c
#include <stdint.h>

#define PWM_BASE   0x30000000
#define PWM_CTRL   (*(volatile uint32_t*)(PWM_BASE + 0x00))
#define PWM_PERIOD (*(volatile uint32_t*)(PWM_BASE + 0x04))
#define PWM_DUTY   (*(volatile uint32_t*)(PWM_BASE + 0x08))
#define PWM_STATUS (*(volatile uint32_t*)(PWM_BASE + 0x0C))

#define PWM_CTRL_EN   (1u << 0)   // Enable
#define PWM_CTRL_POL  (1u << 1)   // Polarity (0 = active-high)
```

---

## 2. Example A - LED Fade (reference, ships with the IP)

Source: [`../software/pwm_test.c`](../software/pwm_test.c).

**What it does**
1. Sets `PERIOD = 1024` → PWM frequency ≈ 11.7 kHz.
2. Sets `DUTY = 0` (LED off).
3. Enables PWM.
4. In an infinite loop, sweeps `DUTY` from 0 up to `PERIOD` and back down, producing a smooth fade-up / fade-down.

**Key lines**
```c
PWM_PERIOD = 1024;
PWM_DUTY   = 0;
PWM_CTRL   = PWM_CTRL_EN;      // enable, active-high

while (1) {
    for (uint32_t d = 0; d < 1024; d += 8) { PWM_DUTY = d; short_delay(2000); }
    for (uint32_t d = 1024; d > 0; d -= 8) { PWM_DUTY = d; short_delay(2000); }
}
```

**Expected output**
- LED0 fades up over ~1 s, then fades down over ~1 s, repeating.
- UART prints `Cycle done. DUTY back to 0.` every full cycle.

---

## 3. Example B - Fixed Brightness LED

Sets LED0 to a constant 25 % brightness.

```c
int main(void) {
    PWM_PERIOD = 1000;              // 12 kHz PWM
    PWM_DUTY   = 250;               // 25 % duty
    PWM_CTRL   = PWM_CTRL_EN;       // enable, active-high

    printf("LED at 25%% brightness\n");
    while (1) { /* nothing to do; PWM runs on its own */ }
    return 0;
}
```

**Expected output**: LED0 lights at roughly 25 % brightness and holds it. No CPU cycles are spent on the PWM after the setup.

---

## 4. Example C - Runtime Duty Adjust from UART Input

Illustrates that duty can be updated at any time from software without stopping the PWM.

```c
// Assumes a simple getchar_uart() blocking call is available in your BSP.
int main(void) {
    PWM_PERIOD = 100;                       // 120 kHz - fast
    PWM_DUTY   = 50;                        // start at 50 %
    PWM_CTRL   = PWM_CTRL_EN;

    printf("Type 0..9 to set brightness in 10%% steps.\n");
    while (1) {
        char c = getchar_uart();
        if (c >= '0' && c <= '9') {
            uint32_t pct = (uint32_t)(c - '0') * 10u;   // 0..90
            PWM_DUTY = (pct * 100u) / 100u;             // PERIOD * pct / 100
            printf("Set DUTY = %u (%u%%)\n", (unsigned)PWM_DUTY, (unsigned)pct);
        }
    }
    return 0;
}
```

---

## 5. Example D - Servo Pulse (~50 Hz, 1-2 ms pulse)

Standard hobby servos expect a 50 Hz signal with a 1-2 ms high pulse (1 ms = full CCW, 1.5 ms = center, 2 ms = full CW).

At 12 MHz:
- Period of 50 Hz → `PERIOD = 12_000_000 / 50 = 240_000` ticks.
- 1 ms → `DUTY = 12_000` ticks.
- 1.5 ms → `DUTY = 18_000`.
- 2 ms → `DUTY = 24_000`.

```c
int main(void) {
    PWM_PERIOD = 240000u;         // 50 Hz
    PWM_DUTY   = 18000u;          // 1.5 ms -> servo center
    PWM_CTRL   = PWM_CTRL_EN;

    // Slowly sweep the servo from 1 ms to 2 ms and back.
    while (1) {
        for (uint32_t d = 12000; d <= 24000; d += 100) {
            PWM_DUTY = d;
            short_delay(100000);
        }
        for (uint32_t d = 24000; d >= 12000; d -= 100) {
            PWM_DUTY = d;
            short_delay(100000);
        }
    }
}
```

Wire the FPGA `pwm_out` pin (through a level shifter or 5 V-tolerant buffer, if your servo requires 5 V logic) to the servo's signal line. Provide the servo its own 5 V supply and a common ground with the FPGA board.

---

## 6. Reading STATUS (Debug)

`STATUS` is optional and read-only. It provides:
- Bit 0 (`RUNNING`): mirror of `CTRL.EN`.
- Bits `[31:16]`: lower 16 bits of the live counter — useful for eyeballing the PWM during single-step or scope-triggering.

```c
uint32_t s = PWM_STATUS;
uint32_t running = s & 1u;
uint32_t cnt     = (s >> 16) & 0xFFFFu;
printf("PWM running=%u, counter[15:0]=%u\n",
       (unsigned)running, (unsigned)cnt);
```

---

## 7. Build & Run

From the reference `TASK_4/` project:

```bash
cd Firmware
make clean
make pwm_test.bram.hex       # builds the firmware hex

cd ../RTL
make build                   # yosys + nextpnr + icepack -> SOC.bin
make flash                   # flashes bitstream via iceprog
make terminal                # opens picocom at 9600 baud
```

On success, LED0 fades on the board and the UART terminal prints the messages listed in the User Guide.
