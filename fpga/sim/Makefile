# Makefile for I2C/SPI Co-Processor Verification


# Configuration ================================================================
# Vivado installation
VIVADO_BIN ?= C:/AMDDesignTools/2025.2/Vivado/bin

# Directory Structure
RTL_DIR    := ../rtl
SIM_DIR    := .
BFM_DIR    := bfm
PKG_DIR    := pkg
COMMON_DIR := common
BUILD_DIR  := build

# Simulation Parameters
TOP_MODULE := tb_top
SNAPSHOT   := sim_snapshot
TEST       ?= all

# Tools
XVLOG := $(VIVADO_BIN)/xvlog
XELAB := $(VIVADO_BIN)/xelab
XSIM  := $(VIVADO_BIN)/xsim


# Sources (ABS paths) ==========================================================
RTL_SOURCES := \
	$(RTL_DIR)/bus/i2c_debounce.sv \
	$(RTL_DIR)/bus/i2c_slave.sv \
	$(RTL_DIR)/bus/spi_slave.sv \
	$(RTL_DIR)/core/register_file.sv \
	$(RTL_DIR)/io/seven_seg.sv

TB_SOURCES := \
	$(PKG_DIR)/tb_pkg.sv \
	$(BFM_DIR)/i2c_master_bfm.sv \
	$(BFM_DIR)/spi_master_bfm.sv \
	$(COMMON_DIR)/scoreboard.sv \
	$(COMMON_DIR)/test_base.sv \
	tb_top.sv

ABS_ALL_SOURCES := $(abspath $(RTL_SOURCES) $(TB_SOURCES))


# Flags ========================================================================
XVLOG_FLAGS := -sv -nolog
XELAB_FLAGS := -debug typical -nolog
XSIM_FLAGS  := -R


# Targets =======================================================================
.PHONY: all
all: sim

# 1. Compile
# FIX: Use Python to create dir safely on both Windows and Linux
.PHONY: compile
compile:
	@echo "=========================================="
	@echo "  Compiling SystemVerilog sources..."
	@echo "=========================================="
	@python -c "import os; os.makedirs('$(BUILD_DIR)', exist_ok=True)"
	cd $(BUILD_DIR) && $(XVLOG) $(XVLOG_FLAGS) $(ABS_ALL_SOURCES) -log compile.log

# 2. Elaborate
.PHONY: elaborate
elaborate: compile
	@echo "=========================================="
	@echo "  Elaborating design..."
	@echo "=========================================="
	cd $(BUILD_DIR) && $(XELAB) $(XELAB_FLAGS) $(TOP_MODULE) -s $(SNAPSHOT) -log elaborate.log

# 3. Simulate
# FIX: Use Python for copy
.PHONY: sim
sim: elaborate
	@echo "=========================================="
	@echo "  Running simulation (TEST=$(TEST))..."
	@echo "=========================================="
	cd $(BUILD_DIR) && $(XSIM) $(SNAPSHOT) -testplusarg "TEST=$(TEST)" $(XSIM_FLAGS) -log simulation.log
	@echo "------------------------------------------"
	@echo "  Copying log to ./sim_output.log"
	@python -c "import shutil; shutil.copy('$(BUILD_DIR)/simulation.log', 'sim_output.log')"
	@echo "------------------------------------------"

# Run specific test shortcut
.PHONY: test-%
test-%:
	$(MAKE) sim TEST=$*

# View waveforms
.PHONY: wave
wave:
	gtkwave $(BUILD_DIR)/tb_top.vcd &

# Cleanmake
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@python -c "import shutil, os; shutil.rmtree('$(BUILD_DIR)', ignore_errors=True)"
	@python -c "import os; os.remove('sim_output.log') if os.path.exists('sim_output.log') else None"

# Help
.PHONY: info
info:
	@echo "Build Directory: $(abspath $(BUILD_DIR))"
	@echo "Sources:"
	@for f in $(ABS_ALL_SOURCES); do echo "  $$f"; done