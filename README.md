# 5-Stage Pipelined RISC-V CPU (Verilog)

## Overview
This repository contains the design and verification of a **5-stage pipelined RISC-V processor**
implemented using **Verilog HDL**.  
The processor follows the classical pipeline stages:
Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM), and Write Back (WB).

The design demonstrates core computer architecture concepts including pipelining,
data hazard handling, and data forwarding.

---

## Features
- 5-stage pipelined datapath (IF, ID, EX, MEM, WB)
- Pipeline registers: IF/ID, ID/EX, EX/MEM, MEM/WB
- RAW data hazard handling
- EX/MEM and MEM/WB forwarding logic
- Stall control logic (NOP-safe)
- Modular RTL design
- Verified using waveform-based simulation

---

## Supported Instructions
- ADD
- SUB
- ADDI
- NOP

---

## Hazard Handling
- ALU-to-ALU data hazards resolved using forwarding
- Stall logic designed for load-use hazards (future extension)
- Forwarding priority: EX/MEM over MEM/WB

---

## Simulation & Verification
- Simulator: **Icarus Verilog**
- Waveform Viewer: **EPWave**
- Verified correct instruction flow, forwarding behavior, and write-back control

---

## How to Run
```bash
iverilog -g2012 src/design.sv tb/cpu_tb.sv
vvp a.out
GitHub Repository:
👉 https://github.com/SUBHOJIT-tech/riscv-5stage-pipelined-cpu

Project Type:
👉 RTL Design & Verification (Verilog HDL)

Simulation Tools:
👉 Icarus Verilog
👉 EPWave (Waveform Analysis)

Waveform Verification:
👉 Included in repository (/waveforms directory)

Issues & Bug Reports:
👉 https://github.com/SUBHOJIT-tech/riscv-5stage-pipelined-cpu/issues

Contact Email:
📧 subhojitbebarta123@gmail.com
