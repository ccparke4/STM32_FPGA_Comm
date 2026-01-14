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

## Entry 3: SPI Stress Test & Pipeline Bug Fix
__Date:__ 01/12/2026

### __Objectives__
* Implement high-speed stress test for SPI link
* Verify data integrity at max throughput
* Identify and fix any timing or protocol issues

### __Test Design__
Modified `StartSpiTask` to perform single-byte transactions at max rate:
* __Method:__ Send incrementing counter (0-255), verify echo = prev. byte
* __Rate:__ ~50k Tx/s 
* __Verification:__ `rx_byte` should be equal to `tx_byte - 1` due to pipeline latency
```c
// stress test verif. logic
expected_val = tx_byte - 1;     // FPGA echoes prev. byte
if (rx_byte != expected_val) {
    error_count++;
}
```


### __Failure Observed___
* __Symptom:__ 100% error rate. MISO always returned 0x00.
* __Console Output:__
```
Starting SPI Stress Test...
FAIL: Tx: 01, Rx: 00
FAIL: Tx: 02, Rx: 00
...
Transfers: 5000 | Errors: 4999 | Last Rx: 0x00
```

* __Logic Analyzer:__ Confirmed MOSI=0x19, MISO=0x00 

### __Root Cause Analysis__
The original SPI slave reset `byte_to_send` to 0x00 whenever CS went inactive:
```systemverilog
// BUG: State cleared between each Tx
if (!cs_active) begin
    bit_cnt         <= '0;
    byte_to_send    <= 8'h00;   // ISSUE: loses prev. byte
end
```

With 1'B transactions (CS toggles between each byte), the FPGA never retains the Rx'd data to echo.

__Protocol Mismatch__
| Test Type | CS Behavior | FPGA State |
|-----------|-------------|------------|
| 4'B packet | CS held low | State preserved |
| 1'B stress | CS toggles each byte | State reset |

### __Solution__
Added persistent `last_byte` reg. that survives CS transitions:
```systemverilog
logic [7:0] last_byte;  // persists

always_ff @(posedge clk) begin
    if (cs_falling) begin
        // CS just went active - load previous byte to send
        shift_out <= last_byte;
        bit_cnt   <= 3'd0;
    end else if (!cs_active) begin
        // CS inactive - only reset bit counter, NOT data
        bit_cnt <= 3'd0;
    end else begin
        // Normal SPI operation...
        if (bit_cnt == 3'd7) begin
            last_byte <= {shift_in[6:0], mosi_sync[1]};  // Save for next transaction
        end
    end
end
```

__Key Changes:__
| Component | Before | After |
|-----------|--------|-------|
| Data persistance | Cleared on CS high | `last_byte` survives |
| MISO preload | On SCLK falling (late) | On CS falling (early) |
| CS sync depth | 2-stage (`cs_sync[1]`) | 3-stage (`cs_sync[2]`) |

### __Verification (Pending)__
- [x] Rebuild bitstream w/ fixes
- [x] Re-run stress test
- [x] verify 0% error rate at 50k tx's
- [x] Capture logic analyzer showing correct echo (see phase1_verification.md)

## Entry 4: Stress Test Verification - PASS
__Date:__ 01/12/2026

### __Test Config__
| Parameter | Value |
|-----------|-------|
| SPI clock | 3.9MHz|
| Tx Size | 1'B |
| CS Toggle | Every Byte |
| Verification | Echo previous byte |

### __Results__

#### Console Output (SWV ITM)
```
Transfers: 6655000 | Errors: 0 | Last Rx: 0x16
Transfers: 6660000 | Errors: 0 | Last Rx: 0x9E
System Alive: 56 seconds | FPGA Link Active
...
Transfers: 6705000 | Errors: 0 | Last Rx: 0x66
Transfers: 6710000 | Errors: 0 | Last Rx: 0xEE
Transfers: 6715000 | Errors: 0 | Last Rx: 0x76
```

#### Logic Analyzer Capture
Verified correct pipeline behavior:
![SPI Stress Test - Logic Analyzer](phase1/screenshots/stress_spi_LA_00.png)

### __Performance Metrics__
| Metric | Value |
|--------|-------|
| Total Transfers | 6,715,000+ |
| Error Count | 0 |
| Error Rate | 0.000% |
| Throughput | ~120,000 bytes/sec |
| Test Duration | 56+ seconds |

### __Verification Checklist__
- [x] MISO echoes previous MOSI byte
- [x] Zero errors over millions of transfers
- [x] 7-segment display updates correctly
- [x] Logic analyzer confirms timing

## Entry 5: DMA Intgration & Sync. Fix
__Date:__ 01/13/2026

### __Objectives__
- Migrate from CPU-polled SPI to DMA-based transfers
- Establish stable burst transfers (64'B packets)
- Eliminate 'bit-slip' errors observed during high-speed burst transitions.

### __Issue: "1-bit Left Shift"__
During initial DMA testing, data integrity was compromised. The FPGA was correctly receiving data, but MISO data read by MCU was shifted left by 1'b (expected 0xC7, Rx'd 0x8E)

- __Analysis:__ The issue was the result of an edge-race condition on the very first bit of a transaction. In standard CPHA=0 mode, the first bit must be valid prior to first clock edg. FPGA logic was shifting `shift_out` on the first rising edge, destroying the MSB before the master could sample it.

### __Fix: SPI Mode 1 Transistion__
Migrated the physical link to SPI Mode 1 (CPOL=0, CPHA=1). Tjis defines clearer setup/hold roles:

1. MISO shifts on rising edge (setup)
2. Master samples on falling edge (sample)

#### __FPGA Implementation (Shift Guard)__
Crucially, in HDL a "shift guard" was implemented to prevent shifting during the setup phase of the very first bit:
```systemverilog
// --- SPI Mode 1 Implementation ---
// Logic: Shift MISO on Rising, Sample MOSI on Falling
if (sclk_rising) begin
// FIX - Don't shift on very first bit
// CPHA, 1st bit must be valid before 1st clock
// we load 'shift_out' at CS_falling (burst reload)
// bit 7 already on wire. Shifting now loses MSB
    if (bit_cnt != 3'd0) begin
        shift_out   <= {shift_out[6:0], 1'b0};
    end
end
```

#### __STM32 Config__
- __Mode:__ SPI Mode 1
- __CPOL:__ Low
- __CPHA:__ 2 Edge

### __Results__
The link is now fully sync'd. DMA tx's of 64-B buffers are 100% accurate. 

| DMA Tx ID | Match Count | Bit Shift | Data Sample |
|-----------|-------------|-----------|-------------|
| 100 | 63/64 | 0 | `Rx[1]: 63` (exp. 63) |
| 200 | 63/64 | 0 | `Rx[1]: C7` (exp. C7) |
| 300 | 63/64 | 0 | `Rx[1]: 2B` (exp. 2B) |

_Note:_ `Rx[0]` is set to be a dummy byt (Shifted: 1 on first byte only), which is planned to be standard for this high-speed SPI implementation.

## Next Steps
- __Software:__ Investigate/Implement a CMD/RSP protocol (Header/Payload/CRC) so the FPGA can be reliably written to with HDL defined Regs.
- __Benchmarking:__ Run throughput & latency tests. Document limits, useful to analyze likely QSPI evolution.
- __Architecture__: Investigate/Implement a BRAM FIFO on FPGA. Move to "Block Read" architecture where the STM32 may be put in a sleep or another state until FPGA has data ready. Need to define MCU side operations/tasks.


