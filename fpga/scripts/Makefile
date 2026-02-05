# handles build and HW programming

# usage
#	make synth		- Run synthesis + implementation + bitstream
#	make program	- program FPGA with existing bitstream
#	make all		- full flow

# Config =======================================================
VIVADO_BIN := C:/AMDDesignTools/2025.2/Vivado/bin
PYTHON     := python

# Directories
SCRIPT_DIR		:= .
PROJECT_ROOT 	:= ..
BUILD_DIR		:= $(PROJECT_ROOT)/build_synth
REPORT_DIR		:= $(PROJECT_ROOT)/reports
DOCS_DIR		:= $(PROJECT_ROOT)/docs

# Files
BIT_FILE		:= $(BUILD_DIR)/top.bit
SYNTH_TCL		:= $(SCRIPT_DIR)/synth_report.tcl
PROGRAM_TCL		:= $(SCRIPT_DIR)/program_fpga.tcl
REPORT_PY		:= $(SCRIPT_DIR)/generate_report.py

# Tools
VIVADO			:= "$(VIVADO_BIN)/vivado"

# Main targs ===================================================

.PHONY: all
all: synth program
	@echo ""
	@echo "================================="
	@echo " Full flow complete"
	@echo "================================="

# Synth & Implementation =======================================

.PHONY: synth
synth:
	@echo "================================="
	@echo "running sythesis and implementation"
	@echo "================================="
	@python -c "import os; os.makedirs('$(BUILD_DIR)', exist_ok=True)"
	$(VIVADO) -mode batch -source $(SYNTH_TCL) -log $(BUILD_DIR)/vivado_synth.log -journal $(BUILD_DIR)/viviado_synth.jou
	@echo ""
	@echo "	Bitstream: $(BIT_FILE)"
	@echo "================================="


# FPGA programming ============================================
.PHONY: program
program: check-bitstream
	@echo "================================="
	@echo "	Programming FPGA"
	@echo "================================="
	$(VIVADO) -mode batch -source $(PROGRAM_TCL) -tclargs $(abspath $(BIT_FILE)) -log $(BUILD_DIR)/vivado_program.log
	@echo ""
	@echo "================================="
	@echo "FPGA programmed successfully!"
	@echo "================================="

.PHONY: check-bitstream
check-bitstream:
	@python -c "import os, sys; sys.exit(0) if os.path.exists('$(BIT_FILE)') else (print('ERROR: Bitstream not found. Run \"make synth\" first.'), sys.exit(1))"

# Documentation ===================================================
.PHONY: report
report:
	@echo "========================================"
	@echo "  Generating Design Report"
	@echo "========================================"
	$(PYTHON) $(REPORT_PY) -r $(REPORT_DIR) -o $(DOCS_DIR)/Design_Report.md
	@echo ""
	@echo "  Report: $(DOCS_DIR)/Design_Report.md"
	@echo "========================================"

.PHONY: docs
docs: report

# quick programming =============================================
.PHONY: flash
flash: program

.PHONY: load
load: program

# Hardware manager GUI ==========================================

.PHONY: gui
gui:
	@echo "Opening Vivado Hardware Manager..."
	$(VIVADO) -mode gui &

.PHONY: hw-gui
hw-gui:
	@echo "Opening Hardware Manager only..."
	$(VIVADO) -mode batch -source -c "open_hw_manager; connect_hw_server; open_hw_target" &

# Utility targs =================================================
.PHONY: check
check:
	@echo "Checking prerequisites..."
	@echo "  Vivado: $(VIVADO)"
	@-$(VIVADO) -version
	@echo "  Python: $(PYTHON)"
	@$(PYTHON) --version
	@echo "  Build dir: $(BUILD_DIR)"
	@echo "  Bitstream: $(BIT_FILE)"
	@python -c "import os; print('    Status: EXISTS' if os.path.exists('$(BIT_FILE)') else '    Status: NOT FOUND')"

.PHONY: status
status:
	@echo "========================================"
	@echo "  Project Status"
	@echo "========================================"
	@echo "  Bitstream:"
	@python -c "import os; f='$(BIT_FILE)'; print(f'    {f}: EXISTS ({os.path.getsize(f)//1024} KB)' if os.path.exists(f) else f'    {f}: NOT FOUND')"
	@echo ""
	@echo "  Reports:"
	@python -c "import os; [print(f'    {f}') for f in os.listdir('$(REPORT_DIR)') if f.endswith('.csv') or f.endswith('.rpt')]" 2>/dev/null || echo "    No reports found"

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@python -c "import shutil; shutil.rmtree('$(BUILD_DIR)', ignore_errors=True)"
	@python -c "import shutil; shutil.rmtree('$(REPORT_DIR)', ignore_errors=True)"
	@echo "  Done."

.PHONY: clean-reports
clean-reports:
	@echo "Cleaning reports only..."
	@python -c "import shutil; shutil.rmtree('$(REPORT_DIR)', ignore_errors=True)"

# Help ============================================================
.PHONY: help
help:
	@echo ""
	@echo "FPGA Build & Program Makefile"
	@echo "=============================="
	@echo ""
	@echo "Build Targets:"
	@echo "  make synth       - Run synthesis, implementation, generate bitstream"
	@echo "  make program     - Program FPGA with existing bitstream"
	@echo "  make all         - Full flow: synth + program"
	@echo "  make flash       - Alias for 'program'"
	@echo ""
	@echo "Documentation:"
	@echo "  make report      - Generate markdown report with charts"
	@echo ""
	@echo "Utilities:"
	@echo "  make check       - Verify tool installation"
	@echo "  make status      - Show project status"
	@echo "  make gui         - Open Vivado GUI"
	@echo "  make clean       - Remove all build artifacts"
	@echo ""
	@echo "Configuration:"
	@echo "  VIVADO_BIN=$(VIVADO_BIN)"
	@echo ""
	@echo "Examples:"
	@echo "  make synth program              # Build and program"
	@echo "  make program                    # Just reprogram"
	@echo "  make VIVADO_BIN=/opt/Xilinx/Vivado/2025.2/bin synth"
	@echo ""