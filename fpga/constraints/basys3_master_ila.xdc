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
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

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

## JB2 - SDA (bidirectional)
set_property PACKAGE_PIN A16 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]

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
#set_false_path -from [get_ports i2c_scl]
#set_false_path -from [get_ports i2c_sda]
#set_false_path -to [get_ports i2c_sda]

## SPI is async (CDC handled in RTL)
#set_false_path -from [get_ports spi_cs]
#set_false_path -from [get_ports spi_sclk]
#set_false_path -from [get_ports spi_mosi]
#set_false_path -to [get_ports spi_miso]

set_property DRIVE 12 [get_ports i2c_sda]
set_property SLEW SLOW [get_ports i2c_sda]

connect_debug_port u_ila_0/probe0 [get_nets [list {i2c_inst/dbg_reg_addr_r[0]} {i2c_inst/dbg_reg_addr_r[1]} {i2c_inst/dbg_reg_addr_r[2]} {i2c_inst/dbg_reg_addr_r[3]} {i2c_inst/dbg_reg_addr_r[4]} {i2c_inst/dbg_reg_addr_r[5]} {i2c_inst/dbg_reg_addr_r[6]} {i2c_inst/dbg_reg_addr_r[7]}]]
connect_debug_port u_ila_0/probe1 [get_nets [list {i2c_inst/dbg_state_num[0]} {i2c_inst/dbg_state_num[1]} {i2c_inst/dbg_state_num[2]} {i2c_inst/dbg_state_num[3]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {i2c_inst/dbg_bit_cnt[0]} {i2c_inst/dbg_bit_cnt[1]} {i2c_inst/dbg_bit_cnt[2]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {i2c_inst/dbg_shift_reg[0]} {i2c_inst/dbg_shift_reg[1]} {i2c_inst/dbg_shift_reg[2]} {i2c_inst/dbg_shift_reg[3]} {i2c_inst/dbg_shift_reg[4]} {i2c_inst/dbg_shift_reg[5]} {i2c_inst/dbg_shift_reg[6]} {i2c_inst/dbg_shift_reg[7]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {i2c_inst/dbg_tx_data[0]} {i2c_inst/dbg_tx_data[1]} {i2c_inst/dbg_tx_data[2]} {i2c_inst/dbg_tx_data[3]} {i2c_inst/dbg_tx_data[4]} {i2c_inst/dbg_tx_data[5]} {i2c_inst/dbg_tx_data[6]} {i2c_inst/dbg_tx_data[7]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list i2c_inst/dbg_ack_scl_rose]]
connect_debug_port u_ila_0/probe6 [get_nets [list i2c_inst/dbg_addr_match]]
connect_debug_port u_ila_0/probe7 [get_nets [list i2c_inst/dbg_reg_wr_pending]]
connect_debug_port u_ila_0/probe8 [get_nets [list i2c_inst/dbg_rw_bit]]
connect_debug_port u_ila_0/probe9 [get_nets [list i2c_inst/dbg_scl_falling]]
connect_debug_port u_ila_0/probe10 [get_nets [list i2c_inst/dbg_scl_rising]]
connect_debug_port u_ila_0/probe11 [get_nets [list i2c_inst/dbg_scl_sync]]
connect_debug_port u_ila_0/probe12 [get_nets [list i2c_inst/dbg_sda_oe_internal]]
connect_debug_port u_ila_0/probe13 [get_nets [list i2c_inst/dbg_sda_sync]]
connect_debug_port u_ila_0/probe14 [get_nets [list i2c_inst/dbg_start_detect]]
connect_debug_port u_ila_0/probe15 [get_nets [list i2c_inst/dbg_stop_detect]]




connect_debug_port u_ila_0/probe0 [get_nets [list {i2c_inst/reg_addr_r[0]} {i2c_inst/reg_addr_r[1]} {i2c_inst/reg_addr_r[2]} {i2c_inst/reg_addr_r[3]} {i2c_inst/reg_addr_r[4]} {i2c_inst/reg_addr_r[5]} {i2c_inst/reg_addr_r[6]} {i2c_inst/reg_addr_r[7]}]]
connect_debug_port u_ila_0/probe1 [get_nets [list {i2c_inst/bit_cnt[0]} {i2c_inst/bit_cnt[1]} {i2c_inst/bit_cnt[2]} {i2c_inst/bit_cnt[3]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {i2c_inst/shift_reg[0]} {i2c_inst/shift_reg[1]} {i2c_inst/shift_reg[2]} {i2c_inst/shift_reg[3]} {i2c_inst/shift_reg[4]} {i2c_inst/shift_reg[5]} {i2c_inst/shift_reg[6]} {i2c_inst/shift_reg[7]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list i2c_inst/ack_scl_rose]]
connect_debug_port u_ila_0/probe6 [get_nets [list i2c_inst/addr_match]]
connect_debug_port u_ila_0/probe7 [get_nets [list i2c_inst/nack_received]]
connect_debug_port u_ila_0/probe10 [get_nets [list i2c_inst/rw_bit]]
connect_debug_port u_ila_0/probe11 [get_nets [list i2c_inst/scl]]
connect_debug_port u_ila_0/probe12 [get_nets [list i2c_inst/scl_falling]]
connect_debug_port u_ila_0/probe13 [get_nets [list i2c_inst/scl_rising]]
connect_debug_port u_ila_0/probe14 [get_nets [list i2c_inst/sda]]
connect_debug_port u_ila_0/probe17 [get_nets [list i2c_inst/start_detect]]
connect_debug_port u_ila_0/probe18 [get_nets [list i2c_inst/stop_detect]]

set_property OFFCHIP_TERM NONE [get_ports i2c_sda]
