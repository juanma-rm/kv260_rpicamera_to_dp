#############################################################
# Usage
#############################################################

# See README.txt

#############################################################
# General parameters
#############################################################

# Language of the top level file (vhdl or verilog)
TOPLEVEL_LANG = vhdl

# Simulator (questa, ghdl, etc.)
SIM ?= questa

# Generate waveform file
WAVES ?= 1

# Enable GUI mode (for questa)
# GUI=1

# Unit and resolution time
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

#############################################################
# DUT and sources
#############################################################

DUT      = counter_wrapper
TOPLEVEL = $(DUT)
MODULE  := test_$(DUT)

MAKEFILE_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
WORKSPACE_PATH := $(dir $(MAKEFILE_PATH))../../..
SRC_PATH := $(WORKSPACE_PATH)/rtl

VHDL_SOURCES			+= $(SRC_PATH)/$(DUT).vhd
VHDL_SOURCES			+= $(SRC_PATH)/utils_pkg.vhd
VERILOG_SOURCES 		+= $(SRC_PATH)/counter.v
VERILOG_INCLUDE_DIRS	+= $(SRC_PATH)/utils.v

# To simulate several VHDL libraries other than work:
# VHDL_SOURCES_lib1		+= 
# VHDL_SOURCES_lib2		+= 

#############################################################
# Configuration for questa
#############################################################

ifeq ($(SIM), questa)
	
	# Unit and resolution time
	VSIM_ARGS += -t $(COCOTB_HDL_TIMEPRECISION)

	# To simulate several VHDL libraries other than work:
	# VHDL_LIB_ORDER = lib1 lib2
	
	# COMPILE_ARGS affects to both vcom (for vhdl) and vlog (for verilog)
	# VCOM_ARGS += -2008 
	VCOM_ARGS += -autoorder 
	
	# Generate a vcd waveform file
	# SIM_ARGS += --vcd=$(DUT).vcd

endif

#############################################################
# Cocotb makefiles
#############################################################

include $(shell cocotb-config --makefiles)/Makefile.sim

#############################################################
# Clean
#############################################################

clean::
	@rm -rf __pycache__
	@rm -rf .pytest_cache
	@rm -rf sim_build
	@rm -rf modelsim.ini
	@rm -rf results.xml
	@rm -rf transcript
	@rm -rf vsim.wlf