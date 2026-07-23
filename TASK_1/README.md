# Task-1 — Environment Setup & RISC-V Reference Bring-Up

[![Tools](https://img.shields.io/badge/Tools-Yosys%20%7C%20Nextpnr%20%7C%20Icestorm%20%7C%20Iverilog%20%7C%20RISCV%20%7C%20Spike%20-blue)](#)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian-orange)](#)

Name: Keyur Dobariya

## Objective
Complete environment setup and validate RISC-V execution flow.

## Environment Used  
✅ Ubuntu Local Machine

---

# Local Environment Setup

OS:
Ubuntu 26.04

Tools Installed:

- [yosys](https://github.com/YosysHQ/yosys.git): Converts Verilog code into gate-level logic.
- [nextpnr](https://github.com/YosysHQ/nextpnr.git): Places and routes logic onto specific FPGA hardware.
- [icestorm](https://github.com/YosysHQ/icestorm.git): Generates the final bitstream file for Lattice iCE40 FPGAs.
- [iverilog](https://github.com/steveicarus/iverilog.git): Simulates Verilog code to test and verify hardware design.
- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain.git): Compiles C/C++ code into binaries that run on RISC-V processors.
- [spike](https://github.com/riscv-software-src/riscv-isa-sim.git): Simulates a RISC-V processor in software to run and debug binaries.

![installation verification](Installation_verification.png)

---

# Task Execution

[Step 1](Sample/README.md) : Verify that the RISC-V toolchain and execution flow are working correctly by compiling and executing a simple C program.

[Step 2](vsdfpga_labs/README.md) : Run the reference RISC-V firmware on the **VSDSquadron FPGA Mini** and receive UART output on the host system through a USB-to-UART converter.

# Understanding

## 1. Where is the RISC-V program located in the repository?
    The RISC-V program is located inside the software/firmware section of the repository.

    The source program is generally written in C (.c) or Assembly (.S) and contains instructions that will execute on the RISC-V processor.

## 2. How is the program compiled and loaded into memory?
    The program is compiled using the RISC-V GNU Toolchain.
    
    Example:
    riscv64-unknown-elf-gcc program.c -o program

    After compilation:

    Machine instructions are generated.
    Output is converted into memory initialization format (.hex, .mem, etc.).
    During simulation or execution, memory is preloaded with this firmware.

## 3. How does the RISC-V core access memory and memory-mapped IO?
    The RISC-V core communicates using a memory bus.

    The CPU generates:

    Address
    Read Enable
    Write Enable
    Write Data

    The SoC checks the address and decides whether access goes to:

    RAM
    UART
    GPIO
    Other peripherals

## 4. Where would a new FPGA IP block logically integrate in this system?
    A new FPGA IP block integrates inside the SoC as another memory-mapped peripheral.

    System structure:

    CPU
    ↓
    System Bus
    ↓
    Address Decoder
    ├── RAM
    ├── UART
    ├── LED
    └── New IP

    Integration steps:

    1. Create RTL module
    2. Instantiate inside SoC
    3. Assign address range
    4. Connect bus interface
    5. Enable software access

---