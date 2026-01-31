# build.tcl - Recreate vivado proj from src files
# Usage: vivado -mode batch -source build.tcl

set project_name "fpga_comm"
set part_number "xc7a35tcpg236-1"
set top_module "top"

# config
set outputDir ./build_output
file mkdir $outputDir
set_part xc7a35tcpg236-1
set_property target_language Verilog [current_project]

# read sources 
read_verilog -sv [glob ../rtl/*.sv]
read_verilog -sv [glob ../rtl/interface/*.sv]
read_verilog -sv [glob ../rtl/core/*.sv]
# xdc... may use gui for this
# read_xdc ../constraints/pins.xdc

# 3. Synthesis
puts "\[TCL\] Running Synthesis..."
synth_design -top top -flatten_hierarchy rebuilt
write_checkpoint -force $outputDir/post_synth.dcp

# 4. opt & place
puts "\[TCL\] Running Optimization & Placement..."
opt_design
place_design

# 5. Routing
puts "\[TCL\] Running routing..."
route_design

# 6. Report GEN

# Hierarchle utilization - tells exactly which module 