## =============================================================================
## Basys 3 Constraints File
## STM32-FPGA Co-Processing System
## Updated: 2026-01-15
## =============================================================================

## -----------------------------------------------------------------------------
## Clock Signal
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
    set_property IOSTANDARD LVCMOS33 [get_ports clk]
    create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## -----------------------------------------------------------------------------
## Reset Button (BTNC as active-low reset)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports rst_n]
    set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## -----------------------------------------------------------------------------
## I2C Control Plane (JB Pmod Header)
## External 4.7k pull-ups required on SDA and SCL
## -----------------------------------------------------------------------------
## JB1 - SCL
set_property PACKAGE_PIN A14 [get_ports i2c_scl]
    set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]
    set_property PULLUP true [get_ports i2c_scl]

## JB2 - SDA (bidirectional)
set_property PACKAGE_PIN A16 [get_ports i2c_sda]
    set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
    set_property PULLUP true [get_ports i2c_sda]

## -----------------------------------------------------------------------------
## SPI Data Plane (JA Pmod Header) - Existing
## -----------------------------------------------------------------------------
## JA1 - CS (input from STM32)
set_property PACKAGE_PIN J1 [get_ports spi_cs]
    set_property IOSTANDARD LVCMOS33 [get_ports spi_cs]
    
## JA2 - MOSI (input from STM32)
set_property PACKAGE_PIN L2 [get_ports spi_mosi]
    set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]

## JA3 - MISO (output to STM32)
set_property PACKAGE_PIN J2 [get_ports spi_miso]
    set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]

## JA4 - SCLK (input from STM32)
set_property PACKAGE_PIN G2 [get_ports spi_sclk]
    set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]

## -----------------------------------------------------------------------------
## LEDs
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

## -----------------------------------------------------------------------------
## Switches
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]

## -----------------------------------------------------------------------------
## 7-Segment Display Segments (Cathodes)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

## -----------------------------------------------------------------------------
## 7-Segment Display Anodes (Digit Selectors)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN U2 [get_ports {an[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

## -----------------------------------------------------------------------------
## Configuration Options
## -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## -----------------------------------------------------------------------------
## Timing Constraints (async inputs - false paths)
## -----------------------------------------------------------------------------
## I2C is async to fabric clock
set_false_path -from [get_ports i2c_scl]
set_false_path -from [get_ports i2c_sda]
set_false_path -to [get_ports i2c_sda]

## SPI is async (CDC handled in RTL)
set_false_path -from [get_ports spi_cs]
set_false_path -from [get_ports spi_sclk]
set_false_path -from [get_ports spi_mosi]
set_false_path -to [get_ports spi_miso]
