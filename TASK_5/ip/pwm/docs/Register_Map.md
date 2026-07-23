# PWM IP - Register Map

**Base address:** `PWM_BASE` (assigned during SoC integration)
**Reference SoC base:** `0x30000000`
**Register width:** 32 bits
**Access:** Word-aligned only (byte / halfword writes go through `wmask`)

---

## Register Summary

| Offset | Register | Access | Reset       | Description                          |
|--------|----------|--------|-------------|--------------------------------------|
| 0x00   | CTRL     | R/W    | 0x00000000  | Enable and polarity                  |
| 0x04   | PERIOD   | R/W    | 0x00000001  | PWM period in clock ticks (≥ 1)      |
| 0x08   | DUTY     | R/W    | 0x00000000  | High time in clock ticks             |
| 0x0C   | STATUS   | R      | -           | Debug status (running + counter)     |

Reads from any other offset return `0x00000000`. Writes to any other offset are silently ignored.

---

## CTRL (Offset 0x00) — R/W

Controls the operating state of the PWM.

| Bits    | Name     | Access | Reset | Description                                                    |
|---------|----------|--------|-------|----------------------------------------------------------------|
| 31 : 2  | *reserved* | R/W  | 0     | Reserved. Read as 0. Writes ignored (may be stored, do not rely).|
| 1       | POL      | R/W    | 0     | Polarity. `0` = active-high (pwm_out high while cnt < DUTY). `1` = active-low. |
| 0       | EN       | R/W    | 0     | Enable. `1` = PWM output enabled and counter runs. `0` = counter held at 0, `pwm_out` forced to inactive level.|

**Read value convention:** Only bits `[1:0]` reflect operational state; all other bits read as 0 in the reference implementation.

---

## PERIOD (Offset 0x04) — R/W

Sets the PWM period in system-clock ticks.

| Bits    | Name    | Access | Reset      | Description                                       |
|---------|---------|--------|------------|---------------------------------------------------|
| 31 : 0  | PERIOD  | R/W    | 0x00000001 | Number of clock ticks per full PWM cycle (≥ 1). Counter runs `0 .. PERIOD-1`. |

**Notes**
- `PERIOD` **must be ≥ 1** for the PWM to generate a waveform.
- `PERIOD = 0` is treated as a safe-idle case: counter is held at 0 and `pwm_out` is inactive.
- Frequency at 12 MHz system clock: `f_pwm = 12_000_000 / PERIOD`.

**Examples**

| PERIOD | f_pwm at 12 MHz |
|--------|-----------------|
| 24     | 500 kHz         |
| 120    | 100 kHz         |
| 1024   | ≈ 11.7 kHz      |
| 12000  | 1 kHz           |
| 60000  | 200 Hz          |

---

## DUTY (Offset 0x08) — R/W

Sets the on-time (in ticks) within each PWM period.

| Bits    | Name  | Access | Reset      | Description                                              |
|---------|-------|--------|------------|----------------------------------------------------------|
| 31 : 0  | DUTY  | R/W    | 0x00000000 | High-time in ticks. `pwm_out` is active while counter < DUTY. |

**Behavior**
- `DUTY = 0` → output is always inactive.
- `DUTY ≥ PERIOD` → output is always active (fully on).
- Duty updates are edge-aligned: they take effect on the next counter wrap, avoiding glitches.

---

## STATUS (Offset 0x0C) — R (read-only)

Debug / observation register.

| Bits    | Name    | Access | Description                                              |
|---------|---------|--------|----------------------------------------------------------|
| 31 : 16 | CNT[15:0] | R    | Lower 16 bits of the live PWM counter (sampled).         |
| 15 : 1  | *reserved* | R  | Reads as 0.                                              |
| 0       | RUNNING | R      | Mirrors `CTRL.EN`. `1` = PWM is enabled and running.     |

Writes to STATUS are ignored.

---

## Reset Behavior

On synchronous reset (`reset = 1`):

| Register | Reset Value  |
|----------|--------------|
| CTRL     | `0x00000000` |
| PERIOD   | `0x00000001` |
| DUTY     | `0x00000000` |
| Counter  | `0x00000000` |
| `pwm_out`| Inactive level (`POL = 0` → low) |

After reset, `pwm_out` is guaranteed low and the counter is stopped until software programs `PERIOD` and sets `CTRL.EN`.

---

## Access Rules

- All accesses are **32-bit** and **word-aligned**.
- Writes use the standard SoC byte-strobe `wmask[3:0]`. Byte writes are supported: e.g., writing only `CTRL[7:0]` to change EN/POL without disturbing other bytes.
- Reads are combinational and return valid data on the same bus cycle as the address.
- Undefined offsets: reads return `0`, writes are ignored.
