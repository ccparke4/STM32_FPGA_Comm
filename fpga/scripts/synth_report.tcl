# ==============================================================================
# Vivado Synthesis & Implementation Automation Script
# ==============================================================================
# Usage:    vivado -mode batch -source synth_report.tcl
# Output:   reports/*.rpt, reports/*.csv, build_synth/*.bit
# ==============================================================================

set PROJECT_NAME "stm32_fpga_bridge"
set PART "xc7a35tcpg236-1"              ; # Basys 3
set TOP_MODULE "top"
set CLOCK_PERIOD 10.0                   ; # 100MHz

# Directory Setup
set SCRIPT_DIR [file dirname [info script]]
set RTL_DIR [file join $SCRIPT_DIR "../rtl"]
set CONSTRAINT_DIR [file join $SCRIPT_DIR "../constraints"]
set REPORT_DIR [file join $SCRIPT_DIR "../reports"]
set BUILD_DIR [file join $SCRIPT_DIR "../build_synth"]

# RTL Source Files
set RTL_SOURCES [list \
    [file join $RTL_DIR "bus/i2c_debounce.sv"] \
    [file join $RTL_DIR "bus/i2c_slave.sv"] \
    [file join $RTL_DIR "bus/spi_slave.sv"] \
    [file join $RTL_DIR "core/register_file.sv"] \
    [file join $RTL_DIR "io/seven_seg.sv"] \
    [file join $RTL_DIR "top.sv"] \
]
set CONSTRAINT_FILES [list [file join $CONSTRAINT_DIR "basys3.xdc"]]

# Create directories
file mkdir $REPORT_DIR
file mkdir $BUILD_DIR
file mkdir [file join $REPORT_DIR "timing"]
file mkdir [file join $REPORT_DIR "power"]

# ==============================================================================
# HELPER PROCEDURES
# ==============================================================================

# Extract numeric value using regex
proc extract_metric {report pattern} {
    if {[regexp $pattern $report match val]} { 
        # Clean up any whitespace
        return [string trim $val]
    }
    return 0
}

# Safe get timing property
proc safe_get_slack {delay_type} {
    set paths [get_timing_paths -max_paths 1 -delay_type $delay_type -quiet]
    if {[llength $paths] > 0} {
        set slack [get_property SLACK [lindex $paths 0]]
        if {$slack ne ""} { return $slack }
    }
    return 0.0
}

# ==============================================================================
# PROJECT CREATION
# ==============================================================================
puts "========================================================================"
puts "INFO: Creating project: $PROJECT_NAME"
puts "========================================================================"

create_project -force $PROJECT_NAME $BUILD_DIR -part $PART

foreach src $RTL_SOURCES { 
    if {[file exists $src]} { 
        puts "  Adding: $src"
        add_files -norecurse $src 
    } else {
        puts "  WARNING: File not found: $src"
    }
}

foreach xdc $CONSTRAINT_FILES { 
    if {[file exists $xdc]} { 
        puts "  Adding constraints: $xdc"
        add_files -fileset constrs_1 -norecurse $xdc 
    }
}

set_property top $TOP_MODULE [current_fileset]

# ==============================================================================
# PHASE 1: SYNTHESIS
# ==============================================================================
puts ""
puts "========================================================================"
puts "INFO: Running Synthesis..."
puts "========================================================================"

set synth_start [clock seconds]
synth_design -top $TOP_MODULE -part $PART -flatten_hierarchy rebuilt
set synth_end [clock seconds]
set synth_time [expr {$synth_end - $synth_start}]

# --- Generate Synthesis Reports ---
puts "INFO: Generating synthesis reports..."

report_utilization -file [file join $REPORT_DIR "utilization_synth.rpt"]
report_utilization -hierarchical -file [file join $REPORT_DIR "utilization_hierarchical_synth.rpt"]
report_timing_summary -file [file join $REPORT_DIR "timing/timing_synth_summary.rpt"]

# --- Extract Synthesis Metrics ---
set synth_report [report_utilization -return_string]

set synth_lut [extract_metric $synth_report {Slice LUTs[^|]*\|\s*(\d+)}]
set synth_lutram [extract_metric $synth_report {LUT as Memory\s*\|\s*(\d+)}]
set synth_ff     [extract_metric $synth_report {Slice Registers\s*\|\s*(\d+)}]
set synth_bram   [extract_metric $synth_report {Block RAM Tile\s*\|\s*([\d.]+)}]
set synth_dsp    [extract_metric $synth_report {DSPs\s*\|\s*(\d+)}]
set synth_muxf7  [extract_metric $synth_report {F7 Muxes\s*\|\s*(\d+)}]
set synth_muxf8  [extract_metric $synth_report {F8 Muxes\s*\|\s*(\d+)}]
set synth_carry  [extract_metric $synth_report {CARRY4\s*\|\s*(\d+)}]
set synth_io     [extract_metric $synth_report {Bonded IOB\s*\|\s*(\d+)}]
set synth_bufg   [extract_metric $synth_report {BUFG\s*\|\s*(\d+)}]

set synth_wns [safe_get_slack max]

puts "  Synthesis LUTs: $synth_lut"
puts "  Synthesis FFs:  $synth_ff"
puts "  Synthesis WNS:  $synth_wns ns"

# ==============================================================================
# PHASE 2: IMPLEMENTATION
# ==============================================================================
puts ""
puts "========================================================================"
puts "INFO: Running Implementation..."
puts "========================================================================"

set impl_start [clock seconds]
opt_design
place_design
route_design
set impl_end [clock seconds]
set impl_time [expr {$impl_end - $impl_start}]

# --- Generate Implementation Reports ---
puts "INFO: Generating implementation reports..."

# Standard utilization
report_utilization -file [file join $REPORT_DIR "utilization_impl.rpt"]

# HIERARCHICAL UTILIZATION - Key for per-module breakdown!
report_utilization -hierarchical -file [file join $REPORT_DIR "utilization_hierarchical.rpt"]

# Timing reports
report_timing_summary -file [file join $REPORT_DIR "timing/timing_impl_summary.rpt"]
report_timing -max_paths 10 -sort_by slack -file [file join $REPORT_DIR "timing/critical_paths.rpt"]

# Clock utilization
report_clock_utilization -file [file join $REPORT_DIR "clock_utilization.rpt"]

# IO report
report_io -file [file join $REPORT_DIR "io_report.rpt"]

# Power report
report_power -file [file join $REPORT_DIR "power/power_impl.rpt"]

# DRC check
report_drc -file [file join $REPORT_DIR "drc_report.rpt"]

# --- Extract Implementation Metrics ---
set impl_report [report_utilization -return_string]

set impl_lut    [extract_metric $impl_report {Slice LUTs\s*\|\s*(\d+)}]
set impl_lutram [extract_metric $impl_report {LUT as Memory\s*\|\s*(\d+)}]
set impl_ff     [extract_metric $impl_report {Slice Registers\s*\|\s*(\d+)}]
set impl_bram   [extract_metric $impl_report {Block RAM Tile\s*\|\s*([\d.]+)}]
set impl_dsp    [extract_metric $impl_report {DSPs\s*\|\s*(\d+)}]
set impl_muxf7  [extract_metric $impl_report {F7 Muxes\s*\|\s*(\d+)}]
set impl_muxf8  [extract_metric $impl_report {F8 Muxes\s*\|\s*(\d+)}]
set impl_carry  [extract_metric $impl_report {CARRY4\s*\|\s*(\d+)}]
set impl_io     [extract_metric $impl_report {Bonded IOB\s*\|\s*(\d+)}]
set impl_bufg   [extract_metric $impl_report {BUFG\s*\|\s*(\d+)}]

set impl_wns [safe_get_slack max]
set impl_whs [safe_get_slack min]

# Power
set power_report [report_power -return_string]
set total_power   [extract_metric $power_report {\|\s*Total On-Chip Power \(W\)\s*\|\s*([\d.]+)}]
set dynamic_power [extract_metric $power_report {\|\s*Dynamic \(W\)\s*\|\s*([\d.]+)}]
set static_power  [extract_metric $power_report {\|\s*Device Static \(W\)\s*\|\s*([\d.]+)}]

# Max frequency
set max_freq 0
if {$CLOCK_PERIOD > $impl_wns && $impl_wns >= 0} {
    set max_freq [expr {1000.0 / ($CLOCK_PERIOD - $impl_wns)}]
}

puts "  Implementation LUTs: $impl_lut"
puts "  Implementation FFs:  $impl_ff"
puts "  Implementation WNS:  $impl_wns ns"
puts "  Max Frequency:       [format %.2f $max_freq] MHz"

# ==============================================================================
# EXTRACT HIERARCHICAL DATA TO CSV
# ==============================================================================
puts ""
puts "INFO: Extracting hierarchical utilization to CSV..."

set hier_csv [file join $REPORT_DIR "hierarchical_utilization.csv"]
set hier_fp [open $hier_csv w]
puts $hier_fp "instance,module,luts,ffs,bram,dsp"

set hier_report [report_utilization -hierarchical -return_string]
set lines [split $hier_report "\n"]

foreach line $lines {
    # Match table rows with data
    if {[regexp {\|\s*(\S+)\s*\|\s*(\S+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*(\d+)\s*\|} $line match inst mod luts ffs bram dsp]} {
        if {$inst ne "Instance" && $inst ne "---" && ![string match "-*" $inst]} {
            puts $hier_fp "$inst,$mod,$luts,$ffs,$bram,$dsp"
        }
    }
}
close $hier_fp

# ==============================================================================
# EXTRACT CRITICAL PATH INFO
# ==============================================================================
puts "INFO: Extracting critical path details..."

set crit_file [file join $REPORT_DIR "critical_path_summary.txt"]
set crit_fp [open $crit_file w]

catch {
    set worst_path [get_timing_paths -max_paths 1 -delay_type max]
    if {[llength $worst_path] > 0} {
        set path [lindex $worst_path 0]
        puts $crit_fp "============================================"
        puts $crit_fp "CRITICAL PATH ANALYSIS"
        puts $crit_fp "============================================"
        puts $crit_fp "Slack:        [get_property SLACK $path] ns"
        puts $crit_fp "Requirement:  [get_property REQUIREMENT $path] ns"
        puts $crit_fp "Data Path:    [get_property DATAPATH_DELAY $path] ns"
        puts $crit_fp "Logic Delay:  [get_property LOGIC_DELAY $path] ns"
        puts $crit_fp "Net Delay:    [get_property NET_DELAY $path] ns"
        puts $crit_fp "Logic Levels: [get_property LOGIC_LEVELS $path]"
        puts $crit_fp "Start Point:  [get_property STARTPOINT_PIN $path]"
        puts $crit_fp "End Point:    [get_property ENDPOINT_PIN $path]"
    }
}
close $crit_fp

# ==============================================================================
# EXPORT CSV SUMMARY
# ==============================================================================
puts ""
puts "INFO: Generating CSV summary..."

set csv_file [file join $REPORT_DIR "synthesis_summary.csv"]
set fp [open $csv_file w]
puts $fp "metric,value"

# Build Info
puts $fp "project,$PROJECT_NAME"
puts $fp "part,$PART"
puts $fp "top_module,$TOP_MODULE"
puts $fp "clock_period,$CLOCK_PERIOD"
puts $fp "synth_time,$synth_time"
puts $fp "impl_time,$impl_time"

# Synthesis Resources
puts $fp "synth_lut,$synth_lut"
puts $fp "synth_lutram,$synth_lutram"
puts $fp "synth_ff,$synth_ff"
puts $fp "synth_bram,$synth_bram"
puts $fp "synth_dsp,$synth_dsp"
puts $fp "synth_muxf7,$synth_muxf7"
puts $fp "synth_muxf8,$synth_muxf8"
puts $fp "synth_carry,$synth_carry"
puts $fp "synth_io,$synth_io"
puts $fp "synth_bufg,$synth_bufg"

# Implementation Resources
puts $fp "impl_lut,$impl_lut"
puts $fp "impl_lutram,$impl_lutram"
puts $fp "impl_ff,$impl_ff"
puts $fp "impl_bram,$impl_bram"
puts $fp "impl_dsp,$impl_dsp"
puts $fp "impl_muxf7,$impl_muxf7"
puts $fp "impl_muxf8,$impl_muxf8"
puts $fp "impl_carry,$impl_carry"
puts $fp "impl_io,$impl_io"
puts $fp "impl_bufg,$impl_bufg"

# Timing
puts $fp "synth_wns,$synth_wns"
puts $fp "impl_wns,$impl_wns"
puts $fp "impl_whs,$impl_whs"
puts $fp "max_freq,[format %.2f $max_freq]"

# Power
puts $fp "total_power,$total_power"
puts $fp "dynamic_power,$dynamic_power"
puts $fp "static_power,$static_power"

close $fp

# ==============================================================================
# GENERATE BITSTREAM
# ==============================================================================
puts ""
puts "========================================================================"
puts "INFO: Generating Bitstream..."
puts "========================================================================"

set bit_file [file join $BUILD_DIR "${TOP_MODULE}.bit"]
write_bitstream -force -bin_file $bit_file

if {[file exists $bit_file]} {
    set bit_size [file size $bit_file]
    puts "SUCCESS: Bitstream created: $bit_file ([expr {$bit_size / 1024}] KB)"
} else {
    puts "ERROR: Bitstream generation failed!"
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
puts ""
puts "========================================================================"
puts "                        BUILD SUMMARY"
puts "========================================================================"
puts ""
puts "  Resources:"
puts "    LUTs:  $impl_lut / 20800 ([format %.2f [expr {$impl_lut * 100.0 / 20800}]]%)"
puts "    FFs:   $impl_ff / 41600 ([format %.2f [expr {$impl_ff * 100.0 / 41600}]]%)"
puts "    BRAM:  $impl_bram / 50"
puts "    DSP:   $impl_dsp / 90"
puts "    IO:    $impl_io / 106"
puts "    BUFG:  $impl_bufg / 32"
puts ""
puts "  Timing:"
puts "    WNS:      $impl_wns ns"
puts "    WHS:      $impl_whs ns"
puts "    Max Freq: [format %.2f $max_freq] MHz"
puts ""
puts "  Power: $total_power W (Dynamic: $dynamic_power W, Static: $static_power W)"
puts ""
puts "  Build Time: Synth ${synth_time}s, Impl ${impl_time}s"
puts ""
puts "  Reports generated in: $REPORT_DIR/"
puts "========================================================================"

close_project
puts "INFO: DONE."