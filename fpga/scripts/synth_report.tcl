# Vivado synthesis & implementation automation script
# usage:    vivado -mode batch -source synth_report.tcl

# CONFIG ============================================================
set PROJECT_NAME "stm32_fpga_bridge"
set PART "xc7a35tcpg236-1"              ; # Basys 3
set TOP_MODULE "top"                    ; # top module name
set CLOCK_PERIOD 10.0                   ; # 100MHz = 10ns period

# paths relative to script location
set SCRIPT_DIR [file dirname [info script]]
set RTL_DIR [file join $SCRIPT_DIR "../rtl"]
set CONSTRAINT_DIR [file join $SCRIPT_DIR "../constraints"]
set REPORT_DIR [file join $SCRIPT_DIR "../reports"]
set BUILD_DIR [file join $SCRIPT_DIR "../build_synth"]

# SRC FILES
set RTL_SOURCES [list \
    [file join $RTL_DIR "bus/i2c_debounce.sv"] \
    [file join $RTL_DIR "bus/i2c_slave.sv"] \
    [file join $RTL_DIR "bus/spi_slave.sv"] \
    [file join $RTL_DIR "core/register_file.sv"] \
    [file join $RTL_DIR "io/seven_seg.sv"] \
    [file join $RTL_DIR "top.sv"] \
]

# Constraint files
set CONSTRAINT_FILES [list \
    [file join $CONSTRAINT_DIR "basys3.xdc"] \
]

# Create output dirs
file mkdir $REPORT_DIR
file mkdir $BUILD_DIR
file mkdir [file join $REPORT_DIR "modules"]
file mkdir [file join $REPORT_DIR "timing"]
file mkdir [file join $REPORT_DIR "power"]

# Generate timestamp
proc timestamp {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

# --- FIX 1: Fixed write_header syntax error ---
proc write_header {fp title} {
    puts $fp "================================================================================"
    puts $fp " $title"
    puts $fp " Generated: [timestamp]"
    puts $fp "================================================================================"
    puts $fp ""
}

# Create project
puts "INFO: Creating project in $BUILD_DIR"
create_project -force $PROJECT_NAME $BUILD_DIR -part $PART

# Add sources
foreach src $RTL_SOURCES {
    if {[file exists $src]} {
        puts "INFO: Adding source: $src"
        add_files -norecurse $src
    } else {
        puts "WARNING: Source not found: $src"
    }
}

# Add constraints
foreach xdc $CONSTRAINT_FILES {
    if {[file exists $xdc]} {
        puts "INFO: Adding constraints: $xdc"
        add_files -fileset constrs_1 -norecurse $xdc
    }
}

set_property top $TOP_MODULE [current_fileset]

# RUN SYNTH
puts "INFO: Running synth..."
set synth_start [clock seconds]
synth_design -top $TOP_MODULE -part $PART -flatten_hierarchy rebuilt
set synth_end [clock seconds]
set synth_time [expr {$synth_end - $synth_start}]
puts "INFO: Synthesis completed in $synth_time seconds"

# REPORTS
report_utilization -file [file join $REPORT_DIR "utilization_synth.rpt"]
report_utilization -hierarchical -file [file join $REPORT_DIR "utilization_hierarchical.rpt"]
report_timing_summary -file [file join $REPORT_DIR "timing/timing_synth_summary.rpt"]
report_timing -max_paths 10 -file [file join $REPORT_DIR "timing/timing_synth_paths.rpt"]

# Per-module utilization
puts "INFO: Extracting per-module utilization..."
set hier_cells [get_cells -hierarchical -filter {IS_PRIMITIVE == false}]
set module_report [file join $REPORT_DIR "modules/module_utilization.rpt"]
set fp [open $module_report w]
write_header $fp "Per-Module Resource Utilization"
puts $fp [format "%-30s %8s %8s %8s %8s" "Module" "LUTs" "FFs" "BRAM" "DSP"]
puts $fp [string repeat "-" 70]

foreach cell $hier_cells {
    set cell_name [get_property NAME $cell]
    set prims [get_cells -hierarchical -filter "NAME =~ $cell_name/* && IS_PRIMITIVE == true"]
    set lut_count 0
    set ff_count 0
    set bram_count 0
    set dsp_count 0
    
    foreach prim $prims {
        set ref [get_property REF_NAME $prim]
        if {[string match "LUT*" $ref]} { incr lut_count }
        if {[string match "FD*" $ref]} { incr ff_count }
        if {[string match "RAMB*" $ref]} { incr bram_count }
        if {[string match "DSP*" $ref]} { incr dsp_count }
    }
    
    if {$lut_count > 0 || $ff_count > 0} {
        puts $fp [format "%-30s %8d %8d %8d %8d" $cell_name $lut_count $ff_count $bram_count $dsp_count]
    }
}
close $fp

# RUN IMPLEMENTATION
puts "INFO: Running implementation..."
set impl_start [clock seconds]
opt_design
place_design
route_design
set impl_end [clock seconds]
set impl_time [expr {$impl_end - $impl_start}]

# Final Reports
report_utilization -file [file join $REPORT_DIR "utilization_impl.rpt"]
report_timing_summary -file [file join $REPORT_DIR "timing/timing_impl_summary.rpt"]
report_timing -max_paths 20 -sort_by slack -file [file join $REPORT_DIR "timing/timing_impl_paths.rpt"]
report_power -file [file join $REPORT_DIR "power/power_estimate.rpt"]

# --- FIX 2: CSV Generation with Regex (Fixes the crash and missing data) ---
puts "INFO: Generating CSV summary..."
set csv_file [file join $REPORT_DIR "synthesis_summary.csv"]
set fp [open $csv_file w]
puts $fp "metric,value,unit,category"

# Basys 3 Constants
set lut_avail 20800
set ff_avail  41600
set bram_avail 50
set dsp_avail  90

# Regex Parse
set util_report [report_utilization -return_string]
set lut_used 0; set ff_used 0; set bram_used 0; set dsp_used 0

if {[regexp {Slice LUTs\s*\|\s*(\d+)} $util_report match val]} { set lut_used $val }
if {[regexp {Slice Registers\s*\|\s*(\d+)} $util_report match val]} { set ff_used $val }
if {[regexp {Block RAM Tile\s*\|\s*(\d+(\.\d+)?)} $util_report match val]} { set bram_used $val }
if {[regexp {DSPs\s*\|\s*(\d+)} $util_report match val]} { set dsp_used $val }

# Timing Parse
set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
if {$wns == ""} { set wns 0.0 }
set max_freq 0
if {$CLOCK_PERIOD > $wns} {
    set max_freq [expr {1000.0 / ($CLOCK_PERIOD - $wns)}]
}

# Write CSV
puts $fp "lut_used,$lut_used,count,utilization"
puts $fp "ff_used,$ff_used,count,utilization"
puts $fp "lut_available,$lut_avail,count,utilization"
puts $fp "ff_available,$ff_avail,count,utilization"
puts $fp "clock_period,$CLOCK_PERIOD,ns,timing"
puts $fp "wns,$wns,ns,timing"
puts $fp "max_frequency,[format %.2f $max_freq],MHz,timing"
puts $fp "synth_time,$synth_time,seconds,build"
puts $fp "impl_time,$impl_time,seconds,build"

close $fp
close_project
puts "INFO: DONE..."