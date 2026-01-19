# I2C Design Metrics Log
**Device:** Artix-7 35T (Basys 3)
**Target Clock:** 100 MHz (10.000 ns)

## Tracking Table
| Date | Ver | Stage / Milestone | LUTs (%) | FFs (%) | BRAM | WNS (Setup) | WHS (Hold) | Power (Est) (conf.) | Notes |
|:---:|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| 01/19/26 | 1.0 | I2C Slave Baseline | 139 (0.6%) | 178 (0.4%) | 0 | +5.034 ns | +0.156 ns | 0.083W (low) | Initial clean build. I2C + RF + SPI. |
| | | | | | | | | | |
| | | | | | | | | | |

## Metric Definitions
* **LUTs:** Look-Up Tables (Logic utilization). High jumps indicate complex logic added.
* **FFs:** Flip-Flops (Registers).
* **WNS (Worst Negative Slack):** How much "safety margin" the setup timing has.
    * *Positive* = Good (margin).
    * *Negative* = Bad (timing violation).
* **WHS (Worst Hold Slack):** Safety margin for hold timing (race conditions).