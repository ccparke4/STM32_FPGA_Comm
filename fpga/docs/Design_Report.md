# FPGA Synthesis & Implementation Report

**Project:** stm32_fpga_bridge  
**Device:** xc7a35tcpg236-1 (Basys 3)  
**Top Module:** top  
**Clock:** 10.0 ns (100 MHz)

---

## Executive Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Max Frequency** | **225.2 MHz** | Large Headroom |
| **Setup Slack (WNS)** | 5.559 ns | PASS |
| **Hold Slack (WHS)** | 0.149 ns | PASS |
| **LUT Usage** | 0.62% | Good |
| **Total Power** | 0.076 W | estimated |

---

## 1. Resource Utilization

### 1.1 Summary

| Resource | Synthesis | Implementation | Available | Utilization |
|----------|-----------|----------------|-----------|-------------|
| **Slice LUTs** | 129 | 128 | 20,800 | 0.62% |
| **Slice Registers** | 145 | 153 | 41,600 | 0.37% |
| **Block RAM** | 0.0 | 0.0 | 50 | 0.00% |
| **DSP48E1** | 0 | 0 | 90 | 0.00% |
| **Bonded IOB** | 33 | 33 | 106 | 31.13% |
| **BUFG** | 1 | 1 | 32 | 3.12% |

### 1.2 Logic Primitives

| Primitive | Synthesis | Implementation | Purpose |
|-----------|-----------|----------------|---------|
| **LUT as Logic** | 129 | 128 | Combinational logic |
| **LUT as Memory** | 0 | 0 | Distributed RAM |
| **MUXF7** | 0 | 0 | Wide muxes (7-8 inputs) |
| **MUXF8** | 0 | 0 | Wider muxes |
| **CARRY4** | 5 | 5 | Fast carry chains |

---

## 2. Per-Module Breakdown

| Instance | Module | LUTs | FFs | % of Total |
|----------|--------|------|-----|------------|
| `top` | (top) | 128 | 128 | 39.4% |
| `i2c_inst` | i2c_slave | 114 | 114 | 35.1% |
| `(i2c_inst)` | i2c_slave | 72 | 72 | 22.2% |
| `reg_file_inst` | register_file | 11 | 11 | 3.4% |
| `(top)` | (top) | 0 | 0 | 0.0% |


![Module Distribution](charts/module_distribution.png)

---

## 3. Timing Analysis

### 3.1 Summary

| Metric | Value |
|--------|-------|
| **Clock Period** | 10.0 ns |
| **Setup Slack (WNS)** | 5.559 ns |
| **Hold Slack (WHS)** | 0.149 ns |
| **Max Achievable Freq** | 225.2 MHz |
| **Timing Margin** | 125% over 100 MHz |

### 3.2 Critical Path

| Property | Value |
|----------|-------|
| **Slack** | 5.559 ns |
| **Logic Levels** | N/A |
| **Start Point** | `N/A...` |
| **End Point** | `N/A...` |

---

## 4. Power Analysis

| Category | Power (W) |
|----------|-----------|
| **Dynamic** | 0.005 |
| **Static** | 0.072 |
| **Total** | **0.076** |

---

## 5. Build Information

| Metric | Value |
|--------|-------|
| **Synthesis Time** | 83 sec |
| **Implementation Time** | 59 sec |
| **Total Build Time** | 142 sec |

---

## 6. Design Quality

### Strengths
- **56% timing margin** on critical path
- **99% LUTs available** for Core IP expansion
- **Low power** (76 mW) - suitable for embedded applications

### Resource Headroom

| Future Feature | Est. LUTs | After Addition |
|----------------|-----------|----------------|
| DMA Engine | ~500 | 3.02% |
| Packet Processor | ~300 | 4.46% |
| Hardware CRC | ~100 | 4.94% |

---

![Design Dashboard](charts/design_dashboard.png)

---
*Generated automatically from Vivado reports*
