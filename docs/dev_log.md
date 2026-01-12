# Development Log: STM32-FPGA Communication System
## Project Overview
__Goal:__ Established bidirectional SPI comm. between STM32H723ZG and Artix-7 Basys 3 FPGA
__Start Date:__ 01/09/2025

## Entry 1: Project Initialization
__Date:__ 01/10/2025

### __Objectives__
* Set up dev. environments (Vivado, STM32CubeIDE)
* Basic blinky "Hello world" on FPGA 
* Verify toolchain functionality

### __Work Completed__
* Created Vivado project targeting XC7A35T (Basys 3)
* Implemented LED blink design in SystemVerilog
* Programmed FPGA via JTAG
* Configured STM32H723 project
    * FreeRTOS (CMSIS_V2)
    * SPI4 in Full-Duplex Master mode
    * SWV ITM debug output

### __Technical Decisions__
* __What:__ SystemVerilog over Verilog
    * __Why:__ Better type safety, more familiar with
* __What:__ SPI4 over SPI1
    * __Why:__ Pin locality on Nucleo board (PE2, PE4, PE5, PE6)
* __What:__ FreeRTOS
    * __Why:__ Allows system complexity and project evolution given evolving system complexity.
* __What:__ SWV Debug
    * __Why:__ Allows debugging via SWV ITM Data Console, rerouting printf (via overriding _write).

### __Next Steps__
* Implement SPI slave module on FPGA
* Physical wiring
* Verify basic byte transfer

## Entry 2: SPI Slave Implementation
__Date:__ 01/11/2026

### __Objectives__
* Design SPI slave module in SystemVerilog
* Handle clock domain crossing 
* Implement echo + "Hi" response protocol

### __Implementation__
#### 1. Clock Domain Crossing 
The SPI clock (7.8MHz from the STM32) is asynchronous to the FPGA fabric clock (100 MHz). Implemented 3-stage synchronizers to prevent metastability:
```SystemVerilog
logic [2:0] sclk_sync;
always_ff @(posedge clk) begin
    sclk_sync <= {sclk_sync[1:0], sclk}
end
```

#### 2. Edge Detection
Used syncronized signals to detect rising/falling edges:
```SystemVerilog
assign sclk_rising  = (sclk_sync[2:1] == 2'b01);
assign sclk_falling = (sclk_sync[2:1] == 2'b10);
```

#### 3. Protocol Design
*Byte[0]: STM32 sends Counter -> FPGA receives

*Byte[1]: STM32 sends Dummy -> FPGA echos counter

*Byte[2]: STM32 sends Dummy -> FPGA sends 'H' (0x48)

*Byte[3]: STM32 sends Dummy -> FPGA sends 'i' (0x69)

#### 4. Visual Output (7-Segment Display)
To verify data ingress physically, the FPGA parses the received byte and maps it to the on-board 7-segment display.
* __Logic:__ The received rx_byte is split into two 4'b nibbles.
* __Decoding:__ A hex decoder drives the cathodes to display the counter value in real-time.

## Problems & Solutions
### Issue: "Off-by-One' Data Shift
* _Symptom_: received data that was shifted by one byte index (Recv: 72 i instead of Recv: <counter> H i).
* _Root Cause_: The FPGA state machine updated the byte_index at the end of the byte, causing the response logic to skip the "Echo" state (index 0) and jump straight to index 1.
* _Fix_: Adjusted case statement in SystemVerilog to align response indices

## Results
### 1. Console Output (SWV ITM) Packet integrity confirmed at 10Hz update rate.
    System Alive: 0 seconds | FPGA Link Active
    Sent: 1 | Recv: 1 Hi
    ...
    Sent: 9 | Recv: 9 Hi
    System Alive: 1 seconds | FPGA Link Active

### 2. Visual Observation
* The 7-segment display on the Basys 3 increments in perfect sync with the STM32 debug logs, confirming the FPGA is correctly latching the MOSI line.

# Next Steps
* Implement a Command Parser (e.g,. sending specific opcodes to toggle FPGA LEDs)
* Stress test the link by increasing SPI baud rate.