# STM32 H7 + Artix-7 FPGA Co-Processing System

## Overview
High-speed, real-time bridge between a __Nucleo-H723ZG__ and a __Basys 3 (Artix-7 FPGA)__. This project demonstrates heterogeneous computing by offloading low-level I/O and acceleration tasks to the FPGA while maintaining high-level control on the MCU via __FreeRTOS__.

__Key Features:__
* __DMA-Accelerated SPI:__ Non-blocking, full-duplex communication using STM32 DMA controllers (SPI4).
* __Robust Phy Layer:__ Implements _SPI Mode 1 (CPOL=0, CPHA=1)_ with custom shift guard logic on FPGA to ensure data integrity during high-speed transfers.
* __CDC (Clock Domain Crossing):__ 3-stage synchronization logic to bridge asynchronous 7.8MHz SPI and 100MHz FPGA clock domains.
* __Real-Time Diagnostics:__ Integration with STM32 SWV ITM Data Console for debugging.
* __Visual Feedback:__ FPGA parses packets to drive a 7-segment display and LED array.

## Repository Structure
* `firmware/`: STM32CubeIDE project (C, FreeRTOS, HAL).
* `fpga/`: Vivado 2025.2 project (SystemVerilog)
* `docs/`: Detailed __[Development Log](docs/dev_log.md)__ and other technical documentation (TBD).
* `tools/`: External scripting for further development.

## Getting Started
1. __FPGA:__ Open `fpga/` in Vivado and generate bitstream.
2. __Firmware:__ Open `firmware/` in STM32CubeIDE.
3. __Hardware Setup:__ 
    * __CS:__ PE4 (STM32) $\leftrightarrow$ JA1 (FPGA)
    * __SCLK:__ PE2 (STM32) $\leftrightarrow$  JA4 (FPGA)
    * __MISO:__ PE5 (STM32) $\leftrightarrow$ JA2 (FPGA)
    * __GND:__ Connect common ground.

## Current Roadmap
This project is currently in active development.
- [x] **Phase 1: Physical Layer (PHY) & Validation**
    - [x] Establish SPI Master (STM32) and Slave (FPGA) link.
    - [x] Implement CDC synchronization for stable data latching.
    - [x] **DMA Integration:** Migrated from Polling/Interrupts to circular DMA buffers.
    - [x] **Stability Fix:** Solved "1-Bit Left Shift" issue by migrating to SPI Mode 1 with FPGA-side shift guards.
    - [x] Verify data integrity (0% BER) on 64-byte burst packets.
- [ ] **Phase 2: Architecture & Protocol**
    - [ ] **Register Protocol:** Define a packet structure for setting FPGA parameters.
    - [ ] **Split Data Plane:** Implement FPGA BRAM FIFOs to decouple high-speed data acquisition from MCU sleep cycles.
    - [ ] **Benchmarking:** Measure Round-Trip Latency and Max Throughput (MB/s).
    - [ ] **Expansion:** Evaluate "Smart NIC" architecture (STM32 $\to$ FPGA $\to$ ESP32/WiFi).
- [ ] **Phase 3: Application Layer (Acceleration)**
    - [ ] **Workload:** Real-time synthetic pattern generation or edge detection.
    - [ ] **Data Flow:** STM32 configures pipeline $\to$ FPGA processes streaming data $\to$ Results read back via DMA.

---
*For more detailed info, see [docs/dev_log.md](docs/dev_log.md).*
