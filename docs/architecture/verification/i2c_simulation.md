# I2C Slave Simulation Verification
__Date:__ 1/17/2026 <br>
__Module(s) Under Test:__ [i2c_slave.sv](fpga/src/i2c_slave.sv), [i2c_slave.sv](fpga/src/register_file.sv) <br>
__Testbench:__ [tb_i2c_slave.sv](fpga/sim/tb_i2c_slave.sv) <br>
__Status:__ In Progress <br>

## 1. Test Plan 
### 1.1 Test Cases
| ID | Test | Description | Expected Result | Status |
|----|------|-------------|-----------------|--------|
| T1 | Device ID Read | Read register 0x00 | Returns 0xA7 | - |
| T2 | Version Read | Read registers 0x01, 0x02 | Returns 0x01, 0x00 | - |
| T3 | Scratch write/read | Write 0x55 to 0x05, read back | Returns 0x55 | - |
| T4 | Scratch Overwrite | Write 0xAA to 0x05, read back | Returns 0xAA | - |
| T5 | Links Caps Read | Read register 0x10 | Returns `8b'00_01_0_1_0_1` | - |
| T6 | LED Control | Write 0xF0 to 0x20 | `led_out` = 0xF0 | - |
| T7 | Switch Readback | Set `sw_in` = 0x3C, read 0x22 | Returns 0x3C | - |
| T8 | Wrong Address | Send transaction to 0x51 | No ACK | - |
| T9 | Auto-Increment Read | Read 4 bytes starting at 0x00 | Returns 0xA7, 0x01, 0x00, ... | - |
| T10 | Auto-Increment Write | Write bytes to 0x05, 0x06 | Both registers update | - |

### 1.2 Coverage Goals
| Metric | Target |
|--------|--------|
| State Coverage | 100% (all states visited) |
| Transition coverage | 100% (all valid transitions) |
| Register read coverage | All implemented registers |
| Register write coverage | All R/W registers |

## 2. Simulation
### Testbench Architecture
![I2C TB Architecture](imgs/i2c_tb_architecture.png)

## 3. Test Results
### 3.1 Run Log
#### Run 1: YYYY-MM-DD HH:MM

