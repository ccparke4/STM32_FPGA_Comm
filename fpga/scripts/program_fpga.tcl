# get bitstream path from arg or use default
if {$argc > 0} {
    set BIT_FILE [lindex $argv 0]
} else {
    set SCRIPT_DIR [file dirname [info script]]
    set BIT_FILE [file join $SCRIPT_DIR "../build_synth/top.bit"]
}

# verify bitstream exists
if {![file exists $BIT_FILE]} {
    puts "ERROR: Bitstream not found: $BIT_FILE"
    puts "      Run synthesis first: vivado -mode batch -source"
}

puts "======================================================================="
puts "  FPGA Programming"
puts "======================================================================="

# open hw manager
open_hw_manager

# connect to hardare server (local)
connect_hw_server -allow_non_jtag

# Auto-det and open targ
open_hw_target

# get the FPGA device
set hw_device [lindex [get_hw_devices] 0]
puts "INFO: Found device: $hw_device"

# set progamming file
set_property PROGRAM.FILE $BIT_FILE $hw_device

# Program the device
puts "INFO: Programming FPGA..."
program_hw_devices $hw_device

# verify
puts "INFO: Verifying..."
refresh_hw_device $hw_device

puts ""
puts "======================================================================="
puts "  SUCCESS: FPGA programmed successfully"
puts "======================================================================="

# close connections
close_hw_target
disconnect_hw_server
close_hw_manager