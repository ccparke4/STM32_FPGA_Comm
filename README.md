# STM32 H7 + Artix-7 FPGA Co-Processing System

## Overview
High-speed, real-time bridge between a __Nucleo-H723ZG__ and a __Basys 3 (Artix-7 FPGA)__. This project demonstrates heterogeneous computing by offloading low-level I/O and acceleration tasks to the FPGA while maintaining high-level control on the MCU via __FreeRTOS__.

__Key Features:__
* __Full-Duplex SPI Link:__ Custom packet-based protocol designed for reliable, high-speed bidirectional data transfer.
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
- [x] __Phase 1: Physical Layer (PHY)__
    - Establish SPI Master (STM32) and Slave (FPGA) link.
    - Implement CDC syncronization for stable data latching.
    - Verify basic echo protocol.
- [ ] __Phase 2: High-Performance I/O__
    - [ ] Implement DMA (Direct Memory Access) on STM32 to offload CPU.
    - [ ] Increase SPI Clock frequency
    - [ ] Perform long-duration stress testing to measure Bit Error Rate.
    - [ ] Evaluate Quad-SPI Implementation to widen bus from 1'b to 4b to increase bandwidth.
    - [ ] Investigate the implementing/designing a split architecture. Seperating Control vs Data via adding I2C to handle "Out-of-Band" management.
- [ ] __Phase 3: Application Layer (Visual Processing)__
    - [ ] __Potential Workloads (TBD):__ 
        - Real-time Edge Detection (Sobel/Canny).
        - Image Binaritization/Thresholding.
        - Synthetic Pattern Generation?
    - [ ] __Data Flow:__
        - STM32 generates/fetches image frame $\to$ SPI Burst $\to$ FPGA.
        - FPGA acts as a streaming accelerator $\to$ Processed Frame $\to$ Display.

---
*For more detailed info, see [docs/dev_log.md](docs/dev_log.md).*
