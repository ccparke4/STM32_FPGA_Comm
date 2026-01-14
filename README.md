# STM32 H7 + Artix-7 FPGA Co-Processing System

## Overview
High-speed, real-time bridge between a __Nucleo-H723ZG__ and a __Basys 3 (Artix-7 FPGA)__. This project demonstrates heterogeneous computing by offloading low-level I/O and acceleration tasks to the FPGA while maintaining high-level control on the MCU via __FreeRTOS__.

__Key Features:__
* __Dual-Bus Architecture:__ Separate control (I2C) and data (SPI/QSPI/FMC) planes for clean separation of concerns.
* __Adaptive Link:__ Runtime-configurable data plane supporting 1-100+ MB/s throughput scaling.
* __DMA-Accelerated SPI:__ Non-blocking, full-duplex communication using STM32 DMA controllers.
* __Robust PHY Layer:__ SPI Mode 1 with custom shift guard logic ensuring data integrity at speed.
* __CDC (Clock Domain Crossing):__ 3-stage synchronization bridging asynchronous SPI and 100MHz FPGA domains.
* __Real-Time Diagnostics:__ STM32 SWV ITM debug console integration.

## Architecture
![System Block Diagram](docs/architecture/Visualization/SysArchitecture_v0.1.png)

## Repository Structure
* `firmware/`: STM32CubeIDE project (C, FreeRTOS, HAL)
* `fpga/`: Vivado 2025.1 project (SystemVerilog)
* `docs/`: Technical documentation
    * [Development Log](docs/dev_log.md)
    * [Adaptive Link Spec](docs/architecture/adaptive_link_spec.md)
* `tools/`: Scripts and utilities

## Hardware Setup

__Control Plane (I2C):__
TBD...

__Data Plane (SPI):__
| Signal | STM32 | FPGA (Basys 3) |
|--------|-------|----------------|
| CS | PE4 | JA1 |
| SCLK | PE2 | JA4 |
| MOSI | PE6 | JA3 |
| MISO | PE5 | JA2 |



## Roadmap

- [x] __Phase 1: Physical Layer (PHY) & Validation__
    - [x] SPI Master (STM32) ↔ Slave (FPGA) link
    - [x] CDC synchronization for stable data latching
    - [x] DMA integration (circular buffers)
    - [x] Stability fix: SPI Mode 1 + FPGA shift guards
    - [x] Verified 0% BER on 64-byte burst packets

- [ ] __Phase 2: Dual-Bus Architecture__
    - [ ] I2C control plane (register access)
    - [ ] FPGA register file (System, Link, GPIO)
    - [ ] Capability discovery (LINK_CAPS)
    - [ ] Runtime data plane mode switching

- [ ] __Phase 3: Bandwidth Scaling__
    - [ ] Dynamic SPI clock configuration
    - [ ] QSPI data plane (4-wire, 25+ MB/s)
    - [ ] FMC parallel interface (100+ MB/s)
    - [ ] Benchmarking: RTT latency, throughput

- [ ] __Phase 4: Application Layer__
    - [ ] BRAM FIFO for async data buffering
    - [ ] Real-time workload (pattern gen, edge detection)
    - [ ] End-to-end pipeline demonstration

## Getting Started
1. __FPGA:__ Open `fpga/` in Vivado, generate bitstream, program board
2. __Firmware:__ Open `firmware/` in STM32CubeIDE, build and flash
3. __Hardware:__ Connect I2C and SPI lines per tables above
4. __Verify:__ Check SWV console for "FPGA Link Active"

---
*See [docs/dev_log.md](docs/dev_log.md) for detailed implementation notes.*
