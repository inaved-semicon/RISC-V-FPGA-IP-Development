# TASK_5 - Commercial-Grade IP Documentation & Release: PWM IP

This directory is the **commercial-grade release** of the PWM IP developed in `TASK_4`. It follows the exact structure required by Task-5 of the VSDSquadron FPGA Mini program, so that any user with a VSDSquadron FPGA board can integrate and use the IP **without reading the RTL**.

## 30-Second Overview

- **What is this IP?** A single-channel, register-programmable PWM peripheral for the VSDSquadron RISC-V SoC. Configure `PERIOD` and `DUTY` from C, and the IP autonomously drives a PWM waveform on `pwm_out` (routed to on-board LED0 in the reference SoC).
- **How do I integrate it?** Copy `ip/pwm/rtl/pwm.v` into your SoC, instantiate `pwm_ip`, decode a 4 KB address window (base `0x30000000` recommended), route `pwm_out` to a pin. Full instructions in [`ip/pwm/docs/Integration_Guide.md`](ip/pwm/docs/Integration_Guide.md).
- **Where are the docs?** In [`ip/pwm/docs/`](ip/pwm/docs) — User Guide, Register Map, Integration Guide, and Example Usage.
- **How do I test it?** See [`ip/pwm/README.md`](ip/pwm/README.md) — simulation with Icarus Verilog and hardware LED-fade demo on the VSDSquadron FPGA Mini.

## Deliverable Structure (Task-5 Requirement)

```
TASK_5/
└── ip/
    └── pwm/
        ├── rtl/
        │   └── pwm.v                      # PWM IP RTL (synthesizable)
        ├── software/
        │   └── pwm_test.c                 # Reference C driver / demo firmware
        ├── test/
        │   └── pwm_tb.v                   # Icarus Verilog testbench
        ├── docs/
        │   ├── IP_User_Guide.md           # Overview, features, block diagram, model
        │   ├── Register_Map.md            # Bit-accurate register definitions
        │   ├── Integration_Guide.md       # How to plug into a VSDSquadron SoC
        │   └── Example_Usage.md           # Four ready-to-run firmware examples
        └── README.md                      # Top-level IP README (30-second view)
```

## Required Documentation Sections - Mapping to Files

The Task-5 PDF requires ten documentation sections. All are covered:

| # | Section (per Task-5 spec)           | Location                                                             |
|---|--------------------------------------|----------------------------------------------------------------------|
| 1 | IP Overview                          | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §1    |
| 2 | Feature Summary                      | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §2    |
| 3 | Block Diagram                        | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §3    |
| 4 | Register Map                         | [`ip/pwm/docs/Register_Map.md`](ip/pwm/docs/Register_Map.md)         |
| 5 | Software Programming Model           | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §5    |
| 6 | Integration Guide                    | [`ip/pwm/docs/Integration_Guide.md`](ip/pwm/docs/Integration_Guide.md)|
| 7 | Board-Level Usage (VSDSquadron FPGA) | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §7    |
| 8 | Example Software                     | [`ip/pwm/software/pwm_test.c`](ip/pwm/software/pwm_test.c) + [`ip/pwm/docs/Example_Usage.md`](ip/pwm/docs/Example_Usage.md) |
| 9 | Validation & Expected Output         | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §9    |
|10 | Known Limitations & Notes            | [`ip/pwm/docs/IP_User_Guide.md`](ip/pwm/docs/IP_User_Guide.md) §10   |

## Quick Test - Simulation

```bash
cd ip/pwm/test
iverilog -o pwm_tb pwm_tb.v -I ../rtl
vvp pwm_tb
```

Expected result: **five PASS lines** for duty, duty-update, polarity, and both disable-level checks.

## Quick Test - Hardware

Use the reference SoC build in `TASK_4/`:

```bash
cd ../../TASK_4/Firmware && make clean && make pwm_test.bram.hex
cd ../RTL && make build && make flash && make terminal
```

Expected result: **LED0 fades up and down** on the VSDSquadron FPGA Mini; UART prints the demo banner.

## Result

The PWM IP is packaged as a commercial-style, plug-and-play FPGA IP: a single Verilog file, a reference driver, a testbench, and full datasheet-style documentation. A first-time user can integrate it into a VSDSquadron SoC by reading only [`ip/pwm/docs/Integration_Guide.md`](ip/pwm/docs/Integration_Guide.md) — the RTL never needs to be opened.
