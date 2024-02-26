###################################################################
# Xilinx Vivado FPGA Makefile
# Copyright (c) 2016 Alex Forencich
# Copyright (c) 2024 Juan Manuel Reina
###################################################################

#############################################################
# Usage
#############################################################

# Source Vivado environment. Example for 2022.1 in Ubuntu
# source /opt/Xilinx/Vivado/2022.1/settings64.sh

# Makefile usage:
# make all: build Vivado project, synthesise, implement and generate bitstream and xsa files
# make vivado: build Vivado project and open Vivado GUI
# make program: program the FPGA
# make clean: remove output files and project files

#############################################################
# General parameters
#############################################################

PROJECT_NAME = kv260_rpicamera_to_dp
# BD_TOP will be used by platform.tcl when building the top block design
BD_TOP = bd_top
FPGA_PART = XCK26-SFVC784-2LV-C
BOARD_PART = xilinx.com:kv260_som:part0:1.3
BOARD_CONNECTIONS = "som240_1_connector xilinx.com:kv260_carrier:som240_1_connector:1.3"
SYN_NUM_JOBS = 12

# DEV_FLOW values are:
# - vivado: only-HW-based workflow
#	- required input: 1) FPGA RTL/IP/constraints files
#	- output files:  1) a bit file
# - vitis_standalone: Vitis/standalone-based workflow (no extensible to extra kernels)
#	- required input: 1) FPGA RTL/IP/constraints files
#	- intermediate files: 1) bit file
#	- output files: 1) an xsa file containing the bitstream
# - vivado_accelerator: Vivado Accelerator workflow (xmutil or dfx-mgr, no extensible to extra kernels) (https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/docs/vivado_accel_flow.html)
#	- required input: 1) FPGA RTL/IP/constraints files
#	- intermediate files: 1) non-extensisble xsa file
#	- output files:  1) a bitbin file and 2) a dtbo file
# - vitis_platform: Vitis platform workflow (xmutil or dfx-mgr, extensible to extra kernels) (https://xilinx.github.io/kria-apps-docs/creating_applications/2022.1/build/html/docs/vitis_platform_flow.html)
#	- required input: 1) FPGA RTL/IP/constraints files and 2) at least one kernel (Vivado IP and xo)
# 	- intermediate files: 1) extensible xsa file
# 	- output files:  1) an xclbin, 2) a dtbo file and 3) a json file
DEV_FLOW = vivado_accelerator

MAKEFILE_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
WORKSPACE_PATH := $(dir $(MAKEFILE_PATH))..

#############################################################
# Input files
#############################################################

# Source files

SRC_PATH 			= $(WORKSPACE_PATH)/rtl

SRC_VHDL_FILES		+= $(SRC_PATH)/counter_wrapper.vhd # Cannot be VHDL 2008 as it is instantiated directly from Vivado IP integrator
SRC_VHDL_FILES		+= $(SRC_PATH)/pwm.vhd # Cannot be VHDL 2008 as it is instantiated directly from Vivado IP integrator
SRC_VHDL08_FILES 	+= $(SRC_PATH)/utils_pkg.vhd
SRC_VERILOG_FILES 	+= $(SRC_PATH)/counter.v
INC_VERILOG_FILES	+= $(SRC_PATH)/utils.v

SRC_ALL_FILES    	= $(SRC_VHDL_FILES) $(SRC_VHDL08_FILES) $(SRC_VERILOG_FILES) $(INC_VERILOG_FILES)

# Constraints
XDC_FILES 			= $(WORKSPACE_PATH)/constraints/kv260.xdc

# IPs
IP_TCL_FILES 		= $(WORKSPACE_PATH)/ips/platform.tcl
# IP_XCI_FILES 		= 

# Misc

###################################################################
# Main Targets
###################################################################

# Note: all targets are executed from within VIVADO_OUT_PATH folder, where the Vivado project will be generated
# Warning! This folders will be removed each time make clean is done; careful with making this variable point to any folder containing important data
ARTIFACTS_OUT_PATH := $(WORKSPACE_PATH)/output/artifacts
VIVADO_OUT_PATH := $(WORKSPACE_PATH)/output/vivado
VITIS_OUT_PATH := $(WORKSPACE_PATH)/output/vitis
DTBO_OUT_PATH := $(WORKSPACE_PATH)/output/dtbo

ifeq ($(DEV_FLOW),vivado)
all: bit
else ifeq ($(DEV_FLOW),vitis_standalone)
all: xsa_non_extensible
else ifeq ($(DEV_FLOW),vivado_accelerator)
all: bitbin xsa_non_extensible dtbo
else ifeq ($(DEV_FLOW),vitis_platform)
# all: xsa_extensible dtbo # @todo pending to add procedure to generate xclbin from xsa + kernel.xo
$(error Unsupported value for DEV_FLOW: $(DEV_FLOW). This mode is not supported yet)$(eval EXITCODE = 1)
else
$(error Unsupported value for DEV_FLOW: $(DEV_FLOW). Valid values are 'vivado', 'vitis_standalone', 'vivado_accelerator', 'vitis_platform')$(eval EXITCODE = 1)
endif

create_path:
	mkdir -p $(ARTIFACTS_OUT_PATH)
	mkdir -p $(VIVADO_OUT_PATH)
	mkdir -p $(DTBO_OUT_PATH)

vivado: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) vivado_gui

bit: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) $(ARTIFACTS_OUT_PATH)/

bitbin: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bitbin

xsa_non_extensible: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) $(ARTIFACTS_OUT_PATH)/xsa_non_ext

xsa_extensible: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) $(ARTIFACTS_OUT_PATH)/xsa_ext

dtsi: create_path
	$(MAKE) -C $(DTBO_OUT_PATH) -f $(MAKEFILE_PATH) pl.dtsi

dtbo: create_path
	$(MAKE) -C $(DTBO_OUT_PATH) -f $(MAKEFILE_PATH) $(PROJECT_NAME).dtbo

program: create_path
	$(MAKE) -C $(VIVADO_OUT_PATH) -f $(MAKEFILE_PATH) program_hw

clean:
	rm -rf $(ARTIFACTS_OUT_PATH)
	rm -rf $(VIVADO_OUT_PATH)
	rm -rf $(VITIS_OUT_PATH)
	rm -rf $(DTBO_OUT_PATH)

.PHONY: all clean

###################################################################
# Target implementations
###################################################################

# Create Vivado project, add all files, etc.

create_project.tcl: $(MAKEFILE_PATH) $(SRC_VHDL_FILES) $(SRC_VHDL08_FILES) $(SRC_VERILOG_FILES) $(INC_VERILOG_FILES) $(XDC_FILES) $(IP_TCL_FILES) $(IP_XCI_FILES)

	@echo "\n\n\n ----------------- Creating Vivado project... ----------------- \n\n\n: $@"

	# Create project
	echo "create_project -force -part $(FPGA_PART) $(PROJECT_NAME)" > $@
	echo "set_property board_part $(BOARD_PART) [current_project]" >> $@
	echo "set_property board_connections {$(BOARD_CONNECTIONS)} [current_project]" >> $@

	# Add sources
	# echo "add_files -fileset sources_1 $(SRC_ALL_FILES)" >> $@
	echo "read_vhdl {$(SRC_VHDL_FILES)}" >> $@
	echo "read_vhdl -vhdl2008 {$(SRC_VHDL08_FILES)}" >> $@
	echo "read_verilog {$(SRC_VERILOG_FILES) $(INC_VERILOG_FILES)}" >> $@

	# Add define macros stored in $(DEFINES) variable
	rm -rf defines.v
	touch defines.v
	for x in $(DEFINES); do echo '`define' $$x >> defines.v; done
	echo "add_files -fileset sources_1 defines.v" >> $@

	# Import source files as copies (required if using v++, otherwise v++ process would complain about missing sources)
	# echo "import_files -norecurse $(SYN_FILES_REL)" >> $@

	# Constraints
	echo "add_files -fileset constrs_1 $(XDC_FILES)" >> $@

	# IPs
	for x in $(IP_XCI_FILES); do echo "import_ip $$x" >> $@; done
	for x in $(IP_TCL_FILES); do echo "source $$x" >> $@; done

$(PROJECT_NAME).xpr: create_project.tcl
	vivado -nojournal -nolog -mode batch -source create_project.tcl

vivado_gui: $(PROJECT_NAME).xpr
	vivado $(PROJECT_NAME).xpr

# Bitstream (bit)
$(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).ltx: $(PROJECT_NAME).xpr
	@echo "\n\n\n ----------------- Running synthesis... ----------------- \n\n\n: $@"
	echo "open_project $(PROJECT_NAME).xpr" > run_synth.tcl
	echo "reset_run synth_1" >> run_synth.tcl
	echo "launch_runs -jobs $(SYN_NUM_JOBS) synth_1" >> run_synth.tcl
	echo "wait_on_run synth_1" >> run_synth.tcl
	vivado -nojournal -nolog -mode batch -source run_synth.tcl

	@echo "\n\n\n ----------------- Running implementation... ----------------- \n\n\n: $@"
	echo "open_project $(PROJECT_NAME).xpr" > run_impl.tcl
	echo "reset_run impl_1" >> run_impl.tcl
	echo "launch_runs -jobs $(SYN_NUM_JOBS) impl_1" >> run_impl.tcl
	echo "wait_on_run impl_1" >> run_impl.tcl
	echo "open_run impl_1" >> run_impl.tcl
	echo "report_utilization -file $(PROJECT_NAME)_utilization.rpt" >> run_impl.tcl
	echo "report_utilization -hierarchical -file $(PROJECT_NAME)_utilization_hierarchical.rpt" >> run_impl.tcl
	vivado -nojournal -nolog -mode batch -source run_impl.tcl

	@echo "\n\n\n ----------------- Generating bin file... ----------------- \n\n\n: $@"
	rm -f $(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).bit
	echo "open_project $(PROJECT_NAME).xpr" > generate_bit.tcl
	echo "open_run impl_1" >> generate_bit.tcl
	echo "write_bitstream -force $(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).bit" >> generate_bit.tcl
	echo "write_debug_probes -force $(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).ltx" >> generate_bit.tcl
	vivado -nojournal -nolog -mode batch -source generate_bit.tcl
	ln -f -s $(VIVADO_OUT_PATH)/$(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).bit $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit
	if [ -e $(VIVADO_OUT_PATH)/$(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).ltx ]; then ln -f -s $(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).ltx $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).ltx; fi

# Bitstream (bitbin)
$(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bitbin: $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit
	@echo "\n\n\n ----------------- Generating bitbin file... ----------------- \n\n\n: $@"
	echo 'all:{$(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit}' > bootgen.bif
	bootgen -w -arch zynqmp -process_bitstream bin -image bootgen.bif

# Generate non-extensible xsa
$(ARTIFACTS_OUT_PATH)/xsa_non_ext: $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit
	@echo "\n\n\n ----------------- Generating non-extensible xsa file... ----------------- \n\n\n: $@"
	# Open project
	echo "open_project $(PROJECT_NAME).xpr" > generate_xsa.tcl
	# write_hw_platform expects bitstream name to be the same as top wrapper
	cp $(PROJECT_NAME).runs/impl_1/$(PROJECT_NAME).bit $(PROJECT_NAME).runs/impl_1/$(BD_TOP)_wrapper.bit
	echo "write_hw_platform -fixed -include_bit -force -file $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).xsa" >> generate_xsa.tcl
	# Run all previous commands
	vivado -nojournal -nolog -mode batch -source generate_xsa.tcl

# Generate extensible xsa
$(ARTIFACTS_OUT_PATH)/xsa_ext: $(PROJECT_NAME).xpr
	@echo "\n\n\n ----------------- Generating extensible xsa file... ----------------- \n\n\n: $@"
	# Open project
	echo "open_project $(PROJECT_NAME).xpr" > generate_xsa.tcl
	# Generate output products 
	echo "delete_ip_run [get_files -of_objects [get_fileset sources_1] $(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd]" >> generate_xsa.tcl
	echo "set_property synth_checkpoint_mode None [get_files $(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd]" >> generate_xsa.tcl
	echo "generate_target all [get_files $(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd]" >> generate_xsa.tcl	; \
	# Configure platform and export xsa
	echo "export_ip_user_files -of_objects [get_files $(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd] -no_script -sync -force -quiet" >> generate_xsa.tcl
	echo "export_simulation -of_objects [get_files $(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd] -directory $(PROJECT_NAME).ip_user_files/sim_scripts -ip_user_files_dir $(PROJECT_NAME).ip_user_files -ipstatic_source_dir $(PROJECT_NAME).ip_user_files/ipstatic -lib_map_path [list {modelsim=$(PROJECT_NAME).cache/compile_simlib/modelsim} {questa=$(PROJECT_NAME).cache/compile_simlib/questa} {xcelium=$(PROJECT_NAME).cache/compile_simlib/xcelium} {vcs=$(PROJECT_NAME).cache/compile_simlib/vcs} {riviera=$(PROJECT_NAME).cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet" >> generate_xsa.tcl
	echo "set_property platform.board_id {board} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.name {name} [current_project]" >> generate_xsa.tcl
	echo "set_property pfm_name {xilinx:board:name:0.0} [get_files -all {$(PROJECT_NAME).srcs/sources_1/bd/$(BD_TOP)/$(BD_TOP).bd}]" >> generate_xsa.tcl
	echo "set_property platform.extensible {true} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.design_intent.embedded {true} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.design_intent.datacenter {false} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.design_intent.server_managed {false} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.design_intent.external_host {false} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.default_output_type {sd_card} [current_project]" >> generate_xsa.tcl
	echo "set_property platform.uses_pr {false} [current_project]" >> generate_xsa.tcl
	echo "write_hw_platform -hw -force -file $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).xsa" >> generate_xsa.tcl
	# Run all previous commands
	vivado -nojournal -nolog -mode batch -source generate_xsa.tcl

# Generate device tree
pl.dtsi:
	test -d device-tree-xlnx || git clone https://github.com/Xilinx/device-tree-xlnx && \
	cd device-tree-xlnx && \
	git checkout xlnx_rel_v2022.1

	echo "hsi open_hw_design $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).xsa" > generate_dtsi.tcl
	echo "hsi set_repo_path device-tree-xlnx" >> generate_dtsi.tcl
	echo "hsi create_sw_design device-tree -os device_tree -proc psu_cortexa53_0" >> generate_dtsi.tcl
	echo "hsi set_property CONFIG.dt_overlay true [hsi::get_os]" >> generate_dtsi.tcl
	echo "hsi generate_target -dir ." >> generate_dtsi.tcl
	echo "hsi close_hw_design $(BD_TOP)_wrapper" >> generate_dtsi.tcl
	xsct -sdx generate_dtsi.tcl

	rm $(ARTIFACTS_OUT_PATH)/psu_*
	@/bin/bash -c 'read -p "Press Enter after manually modifying pl.dtsi modifying it as required (e.g. add board definitions such rpi iic)..."'

# Compile device tree
$(PROJECT_NAME).dtbo: pl.dtsi
	dtc -@ -O dtb -o $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).dtbo ./pl.dtsi 

# Build a Vitis project
vitis_proj: $(PROJECT_NAME).xsa
	echo "platform create -name {$(PROJECT_NAME)} -hw {$(PROJECT_NAME).xsa} -proc {psu_cortexa53_0} -os {standalone} -arch {64-bit} -fsbl-target {psu_cortexa53_0} -out {vitis};platform write" > vitis_proj.tcl
	echo "platform read {vitis/$(PROJECT_NAME)/platform.spr}" >> vitis_proj.tcl
	echo "platform active {$(PROJECT_NAME)}" >> vitis_proj.tcl

# Program the hardware
program_hw: $(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit
	echo "open_hw_manager" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(ARTIFACTS_OUT_PATH)/$(PROJECT_NAME).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl

