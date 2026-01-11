# Title Development Log: STM32-FPGA Communication System
# Project Overview
__Goal:__ Established bidirectional SPI comm. between STM32H723ZG and Artix-7 Basys 3 FPGA
__Start Date:__ 01/09/2025

# Entry 1: Project Initialization
__Date:__ 01/10/2025

## __Objectives__
* Set up dev. environments (Vivado, STM32CubeIDE)
* Basic blinky "Hello world" on FPGA 
* Verify toolchain functionality

## __Work Completed__
* Created Vivado project targeting XC7A35T (Basys 3)
* Implemented LED blink design in SystemVerilog
* Programmed FPGA via JTAG
* Configured STM32H723 project
    * FreeRTOS (CMSIS_V2)
    * SPI4 in Full-Duplex Master mode
    * SWV ITM debug output

## __Technical Decisions__
* __What:__ SystemVerilog over Verilog
    * __Why:__ Better type safety, more familiar with
* __What:__ SPI4 over SPI1
    * __Why:__ Pin locality on Nucleo board (PE2, PE4, PE5, PE6)
* __What:__ FreeRTOS
    * __Why:__ Allows system complexity and project evolution given evolving system complexity.
* __What:__ SWV Debug
    * __Why:__ Allows debugging via SWV ITM Data Console, rerouting printf (via overriding _write).

## __Next Steps__
* Implement SPI slave module on FPGA
* Physical wiring
* Verify basic byte transfer

# Entry 2: SPI Slave Implementation
__Date:__ 01/11/2026

# __Objectives__
* Design SPI slave module in SystemVerilog
* Handle clock domain crossing 
* Implement echo + "Hi" response protocol

# __Implementation__
## Clock Domain Crossing
The SPI clock (7.8MHz from the STM32) is asynchronous to the FPGA fabric clock (100 MHz). Implemented 3-stage synchronizers to prevent metastability:
'''
logic [2:0] sclk_sync;
always_ff @(posedge clk) begin
    sclk_sync <= {sclk_sync[1:0], sclk}
end
'''

## Edge Detection
Used syncronized signals to detect rising/falling edges:
'''
assign sclk_rising  = (sclk_sync[2:1] == 2'b01);
assign sclk_falling = (sclk_sync[2:1] == 2'b10);
'''

## Protocol Design
Byte[0]
- FPGA Response (Garbage)
- FPGA loading response

Byte[1]
- Echo byte 0
- Verify data integrity

Byte[2]
- 0x48('H')

Byte[3]
- 0x69('i')
