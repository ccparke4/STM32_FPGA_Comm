# __State Machines Documentation__
__Version:__ 1.2
__Date:__ 01/17/2026
__Author:__ Trey Parker

## 1. I2C Slave Controller
### 1.1 Overview
- __Type:__ Mealy (out depend on state & in)
- __Clock:__ 100MHz fabric clock'
- __Inputs:__ `scl_rising`, `scl_falling`, `sda`, `start_detect`, `stop_detect`, `reg_rdata`
- __Outputs:__ `sda_drive`, `sda_out`, `reg_wr`, `reg_rd`, `reg_addr`, `reg_wdata`

### 1.2 State Definitions
| State | Encoding | Description |
|-------|----------|-------------|
| `IDLE` | 4'h0 | Waiting for START |
| `GET_ADDR` | 4'h1 | Rx 7'b addr. + R/W bit |
| `ACK_ADDR` | 4'h2 | Sending ACK for addr byte |
| `GET_REG` | 4'h3 | Rx'ing reg addr. byte |
| `ACK_REG` | 4'h4 | Sending ACK for reg addr |
| `WRITE_DATA` | 4'h5 | Rx'ing data byte __from__ MASTER |
| `ACK_WRITE` | 4'h6 | Sending ACK, writing to RF |
| `READ_DATA` | 4'h7 | Tx'ing data __to__ MASTER |
| `WAIT_ACK` | 4'h8 | Waiting for master ACK/NACK |


### 1.3 State Transition Table
| Current State | Condition | Next State | Actions |
|---------------|-----------|------------|---------|
| `IDLE` | `start_detect` | `GET_ADDR` | Reset bit_cnt, shift_reg |
| `IDLE` | else | `IDLE` | - |
| `GET_ADDR` | `scl_rising` & `bit_cnt==7` & addr_match | `ACK_ADDR` | Capture R/W bit |
| `GET_ADDR` | `scl_rising` & `bit_cnt==7` & !addr_match | `IDLE` | - |
| `GET_ADDR` | `scl_rising` & `bit_cnt<7` | `GET_ADDR` | Shift in SDA, `bit_cnt++` |
| `ACK_ADDR` | `scl_falling` & `rw_bit==1` | `READ_DATA` | Load `reg_rdata` to `shift_reg` |
| `ACK_ADDR` | `scl_falling` & `rw_bit==0` & `first_byte` | `GET_REG` | - |
| `ACK_ADDR` | `scl_falling` & `rw_bit==0` & `!first_byte` | `WRITE_DATA` | - |
| `GET_REG` | `scl_rising` & `bit_cnt==7` | `ACK_REG` | 'Latch'(see note) register address |
| `GET_REG` | `scl_rising` & `bit_cnt<7` | `GET_REG` | Shift in SDA, `bit_cnt++` |
| `ACK_REG` | `scl_falling` | `WRITE_DATA` | Clear `first_byte` flag |
| `WRITE_DATA` | `scl_rising` & `bit_cnt==7` | `ACK_WRITE` | - |
| `WRITE_DATA` | `scl_rising` & `bit_cnt<7 | `WRITE_DATA` | Shift out MSB, `bit_cnt++` |
| `ACK_WRITE` | `scl_falling` | `WRITE_DATA` | Assert `reg_wr`, `reg_addr++` |
| `READ_DATA` | `scl_falling` & `bit_cnt==7` | `WAIT_ACK` | - |
| `READ_DATA` | `scl_falling` & `bit_cnt<7` | `READ_DATA` | shift out MSB, `bit_cnt++` |
| `WAIT_ACK` | `scl_rising & sda==1` (NACK) | `IDLE` | Master done |
| `WAIT_ACK` | `scl_rising & sda==0` (ACK) | `READ_DATA` | `reg_addr++`, load next byte |
| _any_ | `stop_detect` | `IDLE` | Clear `addr_match` |

### 1.4 Output Logic (MEALY)
| State | Condition | `sda_drive` | `sda_out` | `reg_wr` | `reg_rd` |
|-------|-----------|-------------|-----------|----------|----------|
| `ACK_ADDR` | - | 1 | 0 | 0 | `rw_bit` & `scl_falling` |
| `ACK_REG` | - | 1 | 0 | 0 | 0 |
| `ACK_WRITE` | - | 1 | 0 | `scl_falling` | 0 |
| `READ_DATA` | - | 1 | `shift_reg[7]` | 0 |
| `WAIT_ACK` | `sda==0` & `scl_rising` | 0 | 1 | 0 | 1 |
| _default_ | - | 0 | 1 | 0 | 0 |

### 1.5 State Diagram
![I2C Mealy FSM](architecture/FSM/i2c_mealy.png)

## 2. SPI Slave Controller
### 2.1 Overview
- __Type:__ Psuedo code, moore-like (no diagram)
- __Clock:__ 100MHz fabric clock
- __SPI Mode:__ Mode 1 (CPOL=0, CPHA=1)
- __Inputs:__ `cs_active`, `cs_falling`, `sclk_rising`, `sclk_falling`, `mosi_sync`
- __Outputs:__ `miso`, `data_received`

### 2.2 Implicit States
SPI slave uses a simple bit counter approach rather than explicit FSM states

| Conidtion | Implicit State | Description |
|-----------|----------------|-------------|
| `!cs_active` | IDLE | CS high, bus inactive |
| `cs_active` & `bit_cnt<7` | SHIFTING | Transferring bits |
| `cs_active` & `bit_cnt==7` | BYTE_COMPLETE | Full byte received |

### 2.3 Sequence
Psuedo/SystemVerilog

cs_falling
    Load shift_out <= last_byte
    Reset bit_cnt <= 0

scl_rising (cs_active)
    if (bit_cnt != 0)
        shift_out <= {shift_out[6:0], 1'b0}     // shift miso

sclk_falling (cs_active)
    shift_in <= {shift_in[6:0], mosi_sync}      // sample mosi
    bit_cnt++
    if (bit_cnt == 7)
        last_byte <= {shift_in[6:0], mosi_sync}
        data_received <= {shift_in[6:0], mosi_sync}
        shift_out <= {shift_in[6:0], mosi_sync} // burst reload

### 2.4 Shift Guard
To prevent the "1'b left shift" bug in SPI mode 1:

``` systemverilog
if (sclk_rising) begin
    // Don't shift on the 1st bit - MSB already on wire from CS_falling
    if (bit_cnt != 3'd0) begin
        shift_out <= {shift_out[6:0], 1'b0};
    end
end
```

## Register File
### 3.1 Overview
- __Type:__ Combinational read, synchronous write
- __No FSM:__ Address decode logic

### 3.2 Write Logic
```
on posedge clk:
    if (reg_wr):
        decode & write to appropiate register
```

### 3.3 Read Logic
```
always_comb:
    case (reg_addr):
        return appropiate register or value
```

# __Revision History__
| __Version__ | __Date__ | __Author__ | __Changes__ |
|-------------|----------|------------|-------------|
| 0.1 | 1/13/26 | Trey P. | Offline SPI controller draft |
| 0.2 | 1/15/26 | Trey P. | Offline I2C controller draft |
| 1.0 | 1/17/26 | Trey P. | Brought drafts online |