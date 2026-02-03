## =============================================================================
## Basys 3 Constraints File
## STM32-FPGA Co-Processing System
## Updated: 2026-02-02
## =============================================================================

## -----------------------------------------------------------------------------
## Clock Signal (100 MHz)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## -----------------------------------------------------------------------------
## Reset Button (BTNC - active low)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## -----------------------------------------------------------------------------
## I2C Control Plane (JB Pmod Header)
## External 4.7k pull-ups REQUIRED on SDA and SCL lines
## -----------------------------------------------------------------------------
## JB1 - SCL (directly directly directly directly directly directly to Pmod pin 1)
set_property PACKAGE_PIN A14 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]

## JB2 - SDA (directly to Pmod pin 2) - Directly to Pmod pin 2) - BIDIRECTIONAL
## Note: Top module must use IOBUF or inout port
set_property PACKAGE_PIN A16 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]

## -----------------------------------------------------------------------------
## SPI Data Plane (JA Pmod Header)
## directly to Pmod pins 1-4
## -----------------------------------------------------------------------------
## JA1 - CS (Directly to Pmod pin 1) - Chip Select (active low)
set_property PACKAGE_PIN J1 [get_ports spi_cs]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs]

## JA2 - MOSI (Directly to Pmod pin 2) - Master Out Slave In
set_property PACKAGE_PIN L2 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]

## JA3 - MISO (Directly to Pmod pin 3) - Master In Slave Out
set_property PACKAGE_PIN J2 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]

## JA4 - SCLK (Directly to Pmod pin 4) - Serial Clock
set_property PACKAGE_PIN G2 [get_ports spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]

## -----------------------------------------------------------------------------
## LEDs [7:0]
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## -----------------------------------------------------------------------------
## Switches [7:0]
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

## -----------------------------------------------------------------------------
## 7-Segment Display - Segments (Active Low Cathodes)
## seg[0]=CA, seg[1]=CB, ..., seg[6]=CG
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]

## -----------------------------------------------------------------------------
## 7-Segment Display - Anodes (Active Low Digit Select)
## an[0]=rightmost digit, an[3]=leftmost digit
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U2 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]

## =============================================================================
## TIMING CONSTRAINTS
## =============================================================================

## -----------------------------------------------------------------------------
## Asynchronous Interface Constraints
## SPI and I2C are driven by external STM32, asynchronous to FPGA sys_clk
## -----------------------------------------------------------------------------

## SPI signals - async to sys_clk
set_false_path -from [get_ports spi_sclk]
set_false_path -from [get_ports spi_cs]
set_false_path -from [get_ports spi_mosi]
set_false_path -to [get_ports spi_miso]

## I2C signals - async to sys_clk
set_false_path -from [get_ports i2c_scl]
set_false_path -from [get_ports i2c_sda]
set_false_path -to [get_ports i2c_sda]

## -----------------------------------------------------------------------------
## Slow/Non-Critical Outputs
## LEDs and display don't need tight timing - human visible
## -----------------------------------------------------------------------------
set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports {seg[*]}]
set_false_path -to [get_ports {an[*]}]

## -----------------------------------------------------------------------------
## Asynchronous Inputs
## Switches and reset are user inputs, async to sys_clk
## -----------------------------------------------------------------------------
set_false_path -from [get_ports {sw[*]}]
set_false_path -from [get_ports rst_n]

## =============================================================================
## CONFIGURATION
## =============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## -----------------------------------------------------------------------------
## Bitstream Options (Optional)
## -----------------------------------------------------------------------------
## Compress bitstream for faster programming
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## Enable CRC checking
set_property BITSTREAM.CONFIG.CRC ENABLE [current_design]
