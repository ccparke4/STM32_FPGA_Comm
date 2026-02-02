# STM32 H7 + Artix-7 FPGA Co-Processing System

**Heterogeneous computing bridge for offloading high-speed I/O and DSP tasks from a Nucleo-H723ZG to a Basys 3 FPGA.**

## Key Features
- **Dual-Bus Architecture:**
  - **Control Plane (I2C):** Register configuration, status polling, and interrupt management.
  - **Data Plane (SPI/QSPI):** High-throughput bulk data streaming (DMA-accelerated).
- **Verified Core:** SystemVerilog RTL verified via Python-driven Transaction Level Modeling (TLM).

## Architecture
| Module | Description | Source |
| :--- | :--- | :--- |
| **I2C Slave** | Control plane interface (Mealy FSM). Configurable address `0x55`. | [`rtl/bus/i2c_slave.sv`](fpga/rtl/bus/i2c_slave.sv) |
| **SPI Slave** | Data plane interface (Mode 1, CPHA=1). Hardware shift guards. | [`rtl/bus/spi_slave.sv`](fpga/rtl/bus/spi_slave.sv) |
| **Register File** | Memory-mapped configuration space. | [`rtl/core/register_file.sv`](fpga/rtl/core/register_file.sv) |

**[System Specification](docs/Technical_Report.md)** *(Register Map & Protocols)*

## Verification (Phase 2 Complete)
The FPGA core is verified using a UVM-style Python/SystemVerilog testbench.

```bash
# Run the full regression suite
cd fpga/sim
make verify

# View waveforms
make wave
