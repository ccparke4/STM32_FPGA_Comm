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
* Byte[0]: STM32 sends Counter -> FPGA receives

* Byte[1]: STM32 sends Dummy -> FPGA echos counter

* Byte[2]: STM32 sends Dummy -> FPGA sends 'H' (0x48)

* Byte[3]: STM32 sends Dummy -> FPGA sends 'i' (0x69)

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
![SPI Stress Test - Logic Analyzer](demo_startup/screenshots/stress_spi_LA_00.png)

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
"shift guard" was implemented to prevent shifting during the setup phase of the very first bit:
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

## Entry 6: Adaptive Link Architecture - Design Phase
__Date:__ 01/14/2026

### __Objectives__
- Define scalable architecture for high-bandwidth FPGA comm. (need to keep latency in mind...)
- Document design
- Estiblish dev. plan

### __Completed Work__
Drafted [adaptive_link_spec.md](architecture/adaptive_link_spec.md) (v0.1) defining dual-bus architecture:

| Plane | Interface | Role |
|-------|-----------|------|
| Control | I2C | Config, status, negotiation |
| Data | SPI/QSPI/FMC | Raw streaming |

### __Design Considerations:__
1. __I2C for control plane__ - standard register access, no custom framing, independent from data path (Careful implementation needed). <br>
2. __Data plane simplicity__ - Raw bytes, avoid protocol overhead   <br>
3. __Capability aiscovery__ - LINK_CAPS register for runtime negotiation <br>
4. __Configurable addressing__ - I2C slave address selectable via ?/? pins (still need to verify this...) (0x50-0x53). <br>

### __Documentation Created__
- [adaptive_link_spec.md](architecture/adaptive_link_spec.md)
    - System Architecture & diagrams
    - Data plane modes (SPI, QSPI, FMC)
    - Register map (systsem, link, GPIO, data engine)
    - I2C protocol draft
    - Drafted Code
    - FPGA module hierarchy

### __Next Steps:__ (COMPLETED 1/15/26)
- [x] STM32 peripheral mapping 
- [x] FPGA pin out mapping/specs
- [x] Verify I2C channel selection

## Entry 7: I2C Control Plane - HDL (Day 1/?)
__Date:__ 01/15/2026

### __Objectives__
- Implement I2C slave module for FPGA
- Create register file per adaptive_link_spec
- Build testbench for verification

### __Work Completed__

**STM32 Configuration:**
- I2C1 enabled (PB6/SCL, PB7/SDA)
- Fast Mode 400kHz
- Rise/Fall time: 100ns/10ns

**FPGA Modules Created/Planned:**
| Module | Description | Status |
|--------|-------------|--------|
| `i2c_slave.sv` | I2C slave FSM with CDC, 7-bit addressing, auto-increment | incomplete |
| `register_file.sv` | Register bank (System 0x00, Link 0x10, GPIO 0x20) | attempt #1 |
| `tb_i2c_slave.sv` | Directed testbench with I2C transaction tasks | - |
| `top_new.sv` | Updated top integrating I2C + existing SPI | - |
| `basys3_constraints.xdc` | Added I2C on JB Pmod (JB1=SCL, JB2=SDA) | - |

**Pin Mapping Finalized:**
| Bus | Signal | STM32 | FPGA |
|-----|--------|-------|------|
| I2C | SCL | PB6 | JB1 (A14) |
| I2C | SDA | PB7 | JB2 (A16) |

### __Next Steps__
- [x] Finish remaining files
    - [x] `i2c_slave.sv`
    - [x] `tb_i2c_slave.sv`
    - [x] `basys3_constraints.xdc`
- [x] Run simulation
- [x] Synthesize and verify timing
- [ ] Hardware test with pull-ups (PUSHED BACK (1/16))

## Entry 8: I2C Control Plane - Integration & Synthesis
__Date:__ 01/16/2026

### __Objectives:__
- Complete I2C slave state machine
- Integrate I2C + SPI into top module 
- Generate bitstream

### _Work Completed__
__I2C Slave FSM (`i2c_slave.sv`):__
- Implemented 9-state FSM: IDLE → GET_ADDR → ACK_ADDR → GET_REG → ACK_REG → WRITE_DATA → ACK_WRITE → READ_DATA → WAIT_ACK
- Features: 7-bit addressing, auto-increment, START/STOP detection
- CDC: 3-stage synchronizers on SCL/SDA (same approach as SPI)

__Top Module Integration (`top.sv`):__
- Integrated I2C slave + register file + existing SPI slave
- Added reset synchronizer
- I2C tristate handling for bidirectional SDA

### __Issue Encountered: Port Name Mismatch__
Bitstream generation failed with:
```
[DRC NSTD-1] Unspecified I/O Standard: Problem ports: JA3
[DRC UCIO-1] Unconstrained Logical Port: Problem ports: JA3
```

__Root Cause:__ 
- Ports declared as `JA1`, `JA2`, `JA3`, `JA4`
- SPI instantiation referenced `spi_cs`, `spi_mosi`, `spi_miso`, `spi_sclk` (undefined signals)
- Constraints file expected `spi_*` names

__Fix:__ 
Adopted functional naming convention (industry standard): <br>
| Port | Physical Pin | Constraint |
|------|--------------|------------|
| `spi_cs` | JA1 (J1) | done |
| `spi_mosi` | JA2 (L2) | done |
| `spi_miso` | JA3 (J2) | done |
| `spi_sclk` | JA4 (G2) | done |

__Notes:__ RTL describes function; constraints handle physical mapping. <br>

### __Current Status__
| Task | Status |
|------|--------|
| `i2c_slave.sv` | Complete |
| `register_file.sv` | Complete |
| `top.sv` | Complete (fixed) |
| `basys3_Master.xdc` | Complete |
| Synthesis | In Progress |
| Testbench | Pending |

### __Next Steps__
- [x] Verify bitstream generation completes
- [x] Create `tb_i2c_slave.sv` testbench
- [ ] Hardware test with 4.7kΩ pull-ups on I2C - PUSHED BACK (1/18-1/19)
- [x] STM32 I2C driver (`fpga_read_reg()` / `fpga_write_reg()`)

## Entry 8: I2C Verification Plan & System Documentation
__Date:__ 01/17/2026 <br>

### __Objectives__
- Finalize simulation environment & files for i2c slave
- Formalize State Machine behavior and Documentation
- Plan integration testing strategy (I2C Independent & I2C + SPI concurrency)

### __Work Completed__
1. __Simulation Environment ([tb_i2c_slave.sv](fpga/sim/tb_i2c_slave.sv))__ Created a self checking SystemVerilog test bench to validate the I2C physical layer and Register file integration.
    - __Bus Modeling:__ Simulated `sda_bus` (pull-up) to handle birdirectional drive.
    - __Test Vector Implementation:__
        - __Target:__ Implemented checks for `DEVICE_ID` (0xA7), ACK/NACK handling, and RF
        - __I/O Control:__ Addde test cases for LED output and Switch input

2. __State Machine Documentation ([state_machines.md](architecture/state_machines.md))__ documented the control logic into a single document tracking different state machines and pseudo-code.
    - __I2C Slave:__ Define as 9 State Mealy Machine
    - __SPI Slave:__ Mostly pseudo-code, counter approach, moore-esque model

3. __Integration Strategy:__
    - Disabled [tb_spi_slave.sv](fpga/sim/tb_spi_slave.sv) in Vivado to isolate I2C verification.
    - Defined validation hierarchy: __Unit Testing__ (independent SPI done, Independent I2C TBD) -> __Integration Testing__ (Test concurrency of systems).

### __Results__
- __Sim Status:__ TBD. Testbench code written and compiles; execution ready...
- __Architecture:__ Block diagrams for FSM and insight into (previously offline) design choices and approach

### __Next Steps__
- [ ] __Execute Unit Test:__ Verify output and waveforms
- [ ] __Integration Planning:__ Draft up combined tb (`tb_system_top`) to simulate both SPI and I2C at the same time.
- [ ] __Integration Testing:__ Simulate `tb_system_top` and validate.
    - Ensure that high-speed SPI does not corrupt I2C (vice versa)
- [ ] __Firmware Integration:__ Return to working with the STM32H7: developing c code, real world tests, 'on-the-fly' peripheral communication config.



