# STM32 - FPGA Communcation Bridge

## Technical Design Report

**Project:** Dual-Plane MCU-FPGA Communication System
**Platform:** STM32H723ZG + Xilinx Aritx-7 (Basys 3)
**Author:** Trey Parker
**Date:** 1/30/2026
**Revision:** 2.0
**Status:** Verification Complete

## Table of Contents

1. Summary
2. System Architecture
3. RTL Implementation
4. Verification Environment
5. Test Results
6. Build & Automation
7. Next Steps: Core IP Development
8. Appendix

## 1. Summary
This project implements a dual-plane communication architecture between an STM32H723ZG microcontroller and an Artix-7 FPGA, separating control operations (I2C) from high-speed data transfer (SPI).

### Key Results

| Metric |  Result |
|--------|---------|
| I2C Control Plane | 100% Pass Rate |
| SPI Data Splane | 0% BER |
| Simulation Coverage | 147 transactions, 99.3% pass rate |
| Verification Environment | BFM + Scoreboard architecture |

### Acheivements
* [x] Full I2C slav state machin with debounce filetring and open-drain support
* [x] SPI slave ith loopback verification mode, need to develop come core IP
* [x] Memory-mapped register file with RO/RW/W1C access types
* [x] SystmVerilog verification environment with golden model checking
* [x] Cross platform build automation (windows/linux)
* [x] Identified and resolved I2C read timing bug via systematic debugging

## 2. System Architecture
### 2.1 Dual-Plane Philosophy
The architecture seperates communication into 2 independent planes, each optimized for its specific use case:
