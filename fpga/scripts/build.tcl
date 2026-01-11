# build.tcl - Recreate vivado proj from src files
# Usage: vivado -mode batch -source build.tcl

set project_name "fpga_comm"
set part_number "xc7a35tcpg236-1"
set top_module "top"

# Create Project
create_project $project_name ./vivado_project -part $part_number -force

# add source files
add_files -norecurse {
	../src/top.sv
	../src/spi_slave.sv
	../src/seven_seg.sv
}

# add constraints
add_files -fileset constrs_1 -norecurse ../constraints/basys3_Master.xdc

# set top module
set_property top $top_module [current_fileset]

# compiler order
update_compiler_order -fileset sources_1

puts "Project created successfully!"
puts "Run 'launch_runs impl_1 -to_step write_bitstream' to build"
