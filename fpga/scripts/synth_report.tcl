# Vivado synthesis & implementation automation script
# usage:    vivado -mode batch -source synth_report.tcl

set PROJECT_NAME "stm32_fpga_bridge"
set PART "xc7a35tcpg236-1"              ; # Basys 3
set TOP_MODULE "top"                    ; # top module name
set CLOCK_PERIOD 10.0                   ; # 100MHz

set SCRIPT_DIR [file dirname [info script]]
set RTL_DIR [file join $SCRIPT_DIR "../rtl"]
set CONSTRAINT_DIR [file join $SCRIPT_DIR "../constraints"]
set REPORT_DIR [file join $SCRIPT_DIR "../reports"]
set BUILD_DIR [file join $SCRIPT_DIR "../build_synth"]

set RTL_SOURCES [list \
    [file join $RTL_DIR "bus/i2c_debounce.sv"] \
    [file join $RTL_DIR "bus/i2c_slave.sv"] \
    [file join $RTL_DIR "bus/spi_slave.sv"] \
    [file join $RTL_DIR "core/register_file.sv"] \
    [file join $RTL_DIR "io/seven_seg.sv"] \
    [file join $RTL_DIR "top.sv"] \
]
set CONSTRAINT_FILES [list [file join $CONSTRAINT_DIR "basys3.xdc"]]

file mkdir $REPORT_DIR
file mkdir $BUILD_DIR

puts "INFO: Creating project..."
create_project -force $PROJECT_NAME $BUILD_DIR -part $PART
foreach src $RTL_SOURCES { if {[file exists $src]} { add_files -norecurse $src } }
foreach xdc $CONSTRAINT_FILES { if {[file exists $xdc]} { add_files -fileset constrs_1 -norecurse $xdc } }
set_property top $TOP_MODULE [current_fileset]

# Helper to extract values using regex
proc extract_metric {report pattern} {
    if {[regexp $pattern $report match val]} { return $val }
    return 0
}

# ==============================================================================
# PHASE 1: SYNTHESIS
# ==============================================================================
puts "INFO: Running Synthesis..."
set synth_start [clock seconds]
synth_design -top $TOP_MODULE -part $PART -flatten_hierarchy rebuilt
set synth_end [clock seconds]

set synth_report [report_utilization -return_string]
set synth_lut    [extract_metric $synth_report {Slice LUTs\s*\|\s*(\d+)}]
set synth_ff     [extract_metric $synth_report {Slice Registers\s*\|\s*(\d+)}]
set synth_bram   [extract_metric $synth_report {Block RAM Tile\s*\|\s*(\d+(\.\d+)?)}]
set synth_dsp    [extract_metric $synth_report {DSPs\s*\|\s*(\d+)}]
# New Metrics
set synth_muxf7  [extract_metric $synth_report {F7 Muxes\s*\|\s*(\d+)}]
set synth_muxf8  [extract_metric $synth_report {F8 Muxes\s*\|\s*(\d+)}]
set synth_carry  [extract_metric $synth_report {CARRY4\s*\|\s*(\d+)}]

set synth_wns [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max]]
if {$synth_wns == ""} { set synth_wns 0.0 }

# ==============================================================================
# PHASE 2: IMPLEMENTATION
# ==============================================================================
puts "INFO: Running Implementation..."
set impl_start [clock seconds]
opt_design
place_design
route_design
set impl_end [clock seconds]

set impl_report [report_utilization -return_string]
set impl_lut    [extract_metric $impl_report {Slice LUTs\s*\|\s*(\d+)}]
set impl_ff     [extract_metric $impl_report {Slice Registers\s*\|\s*(\d+)}]
set impl_bram   [extract_metric $impl_report {Block RAM Tile\s*\|\s*(\d+(\.\d+)?)}]
set impl_dsp    [extract_metric $impl_report {DSPs\s*\|\s*(\d+)}]
# New Metrics
set impl_muxf7  [extract_metric $impl_report {F7 Muxes\s*\|\s*(\d+)}]
set impl_muxf8  [extract_metric $impl_report {F8 Muxes\s*\|\s*(\d+)}]
set impl_carry  [extract_metric $impl_report {CARRY4\s*\|\s*(\d+)}]

set impl_wns [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max]]
if {$impl_wns == ""} { set impl_wns 0.0 }
set impl_whs [get_property SLACK [get_timing_paths -max_paths 1 -delay_type min]]
if {$impl_whs == ""} { set impl_whs 0.0 }

set power_report [report_power -return_string]
set total_power [extract_metric $power_report {\|\s*Total On-Chip Power \(W\)\s*\|\s*(\d+\.\d+)}]

set max_freq 0
if {$CLOCK_PERIOD > $impl_wns} {
    set max_freq [expr {1000.0 / ($CLOCK_PERIOD - $impl_wns)}]
}

# ==============================================================================
# EXPORT DATA
# ==============================================================================
puts "INFO: Generating CSV..."
set csv_file [file join $REPORT_DIR "synthesis_summary.csv"]
set fp [open $csv_file w]
puts $fp "metric,value"

# Main Resources
puts $fp "synth_lut,$synth_lut"
puts $fp "synth_ff,$synth_ff"
puts $fp "synth_bram,$synth_bram"
puts $fp "synth_dsp,$synth_dsp"
puts $fp "impl_lut,$impl_lut"
puts $fp "impl_ff,$impl_ff"
puts $fp "impl_bram,$impl_bram"
puts $fp "impl_dsp,$impl_dsp"

# Detailed Primitives
puts $fp "synth_muxf7,$synth_muxf7"
puts $fp "synth_muxf8,$synth_muxf8"
puts $fp "synth_carry,$synth_carry"
puts $fp "impl_muxf7,$impl_muxf7"
puts $fp "impl_muxf8,$impl_muxf8"
puts $fp "impl_carry,$impl_carry"

# Timing & Power
puts $fp "synth_wns,$synth_wns"
puts $fp "impl_wns,$impl_wns"
puts $fp "impl_whs,$impl_whs"
puts $fp "max_freq,[format %.2f $max_freq]"
puts $fp "total_power,$total_power"

close $fp

puts "INFO: Generating Bitstream..."

# Ensure we write to the build directory
set bit_file [file join $BUILD_DIR "top.bit"]

# -bin_file creates a raw binary (useful for STM32 loading)
# -force overwrites existing files
write_bitstream -force -bin_file $bit_file

puts "INFO: Bitstream generated at $bit_file"

# Check if file actually exists before finishing
if {[file exists $bit_file]} {
    puts "SUCCESS: Bitstream created successfully."
} else {
    puts "ERROR: Bitstream generation failed!"
}

close_project
puts "INFO: DONE."