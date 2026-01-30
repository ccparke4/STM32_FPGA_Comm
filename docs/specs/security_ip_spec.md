# Hardware Security & Counterfeit Detection

## 1. Overview
This specification defines the architecture for the FPGA-based Automated Test Equipment (ATE) block. The IP is designed to perform Post-Silicon Validation and Counterfeit Detection on external components connected to the FPGA.

By leveraging the reconfigurable nature of the FPGA, this system performs both Digital Identity Verification (via JTAG) and Analog Parametric Analysis (via Propagation Delay Characterization) to detect cloned, remarked, or out-of-spec silicon.

### 1.1 Detection Capabilities
The system is designed to detect the following supply chain attacks

| Attack Vector | Description | Detection Method |
|---------------|-------------|------------------|
| remarking / speed binning | slow/cheap chip is laser etched with another part number | **Propagation Delay Analysis:** Measuring I/O response time with <100ps resolution. |
| cloning | Unauth'd copies made at a different fab | **Parametric Fingerprinting:** Analyzing physical switching characteristics. |
| die harvesting | old chips desoldereed from e-waste and sold as new | **Continuity & Aging:** Detecting threshold voltage shifts (via delay) or open pins |
| Fake Identity | Completely different chip inside package | **JTAG IDCODE Audit:** Verifying the hard-coded manufacturer ID. |

## 2. System Architecture
The security IP sits on FPGA's local bus, controlled by STM32 via the existing I2C register file.

### 2.1 Functional Blocks
1. **JTAG Auditor (Digital):** An IEEE 1149.1 master controller that interrogates the Target Access Port of the DUT.
2. **Propagation Delay Analyzer (analog/parametric):** A Time-to-digital converter (TDC) using Xilinx IDELAY primitaives to measure I/O response times within 78 picosecond resolution.
3. **Control Interface:** Memory-mapped registeres exposed to STM32 via I2C.

## 3. Module Specifications

### 3.1 Module A: JTAG Auditor
* **Protocol:** IEEE 1149.1 (standard JTAG)
* **Role:** Master
* **Operation:**
    1. Force DUT Reset (`TMS` high for 5 cycles)
    2. Navigate state machine to `Shift-DR`
    3. Shift out 32-bit **IDCODE** register
    4. Return to idle

* Exptected IDCODEs (reference):
  * `0x6BA00477` (STM32H7 / Cortex-M7)
  * `0x0362D093` (Xilinx Artix-7)

### 3.2 Module B: Propagation Delay Analyzer (TDC)
* **Metric:** Input-to-output propagation delay
* **Methodology:** Dynamic Delay line sweep
    1. FPGA drives stimulus pulse (0 -> 1)
    2. DUT loops signal back
    3. FPGA delays the input signal using `IDELAY2` taps (0-31)
    4. Logic samples the signal to find the "vanishing point" (edge location).
* **Resulution:** ~78ps/tap (at 200MHz ref clock)
* **Equation:** Delay = Tap Count * 78ps.

## 4. Register Map (Address Space `0x40`)
The STM32 controls the IP by writing to the following addresses over I2C

| Offset | Name | R/W | Bit | Description |
|--------|------|-----|-----|-------------|
| 0x40 | `SEC_CTRL` | W | 0 | `START_JTAG`: Trigger IDCODE scan (self-clearing) |
| 0x40 | `SEC_CTRL` | W | 1 | `START_DELAY`: Trigger delay test (self-clearing) |
| 0x41 | `SEC_STATUS` | R | 0 | `JTAG_VALID`: Data ready in registers 0x42-0x45 |
| 0x41 | `SEC_STATUS` | R | 1 | `DELAY_DONE`: Data ready in register 0x46 |
| 0x42 | `JTAG_ID3` | R | `7:0` | IDCODE Bits (Version/Part) |
| 0x43 | `JTAG_ID2` | R | `7:0` | IDCODE Bits (Part Number) |
| 0x44 | `JTAG_ID1` | R | `7:0` | IDCODE Bits [15:8] (Manufacturer) |
| 0x45 | `JTAG_ID0` | R | `7:0` | IDCODE Bits [7:0] (Manufacturer) |
| 0x46 | `DELAY_RES` | R | `4:0` | Tap Count: Measured Delay (0-31) |

## 5. Implementation Roadmap
### Phase 1: Digital Verification (JTAG)
* **Objective:** Succesfully read the IDCODE of the host STM32
* **Hardware:** Connect FPGA PMOD pins to the Nucleo SWD/JTAG header.
* **Success Criteria:** Reading `0x6BA00477` via I2C. (loopback-esque)

### Phase 2: Parametric Verification (TDC)
* **Objective:** Discriminate between a "Short Wire" and a "Long Wire/Buffer."
* **Hardware:** Loopback wire on breadboard
* **Success Criteria:** "Short Wire" reads ~0 taps. "Long wire" reads >2 taps.

### Phase 3: Automated Certification
* **Objective:** Full python/makefile automation
* **Software:** `verify_chip.py` runs on PC that issues a "Certificate of Authenticity" JSON object


