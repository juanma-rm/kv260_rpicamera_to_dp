#!/usr/bin/env python3
"""
Vivado/Vitis Build Script - Python equivalent of Makefile
========================================================

This script replaces the Makefile for building Vivado projects and generating
XSA files for the KV260 RPICamera to DisplayPort project.

Usage:
    python build_vivado_proj.py [parameters]

Parameters:
    --target <value>         Build target to execute (default: all)
        all: Build complete project (default, depends on DEV_FLOW)
        vivado: Create project and open Vivado GUI
        bit: Generate bitstream
        xsa_non_extensible: Generate non-extensible XSA (for vitis_standalone)
        xsa_extensible: Generate extensible XSA (for vitis_platform)
        bitbin: Generate bitbin file
        dtbo: Generate device tree overlay
        xclbin: Generate XCLBIN file
        program: Program the FPGA
        clean: Clean all output directories
    
    --dev-flow <value>       Development flow (default: vitis_standalone)
        vivado: Only hardware workflow
            - Required: FPGA RTL/IP/constraints files
            - Output: Bit file (.bit)
        vitis_standalone: Vitis standalone workflow (no extensible kernels)
            - Required: FPGA RTL/IP/constraints files  
            - Intermediate: Bit file
            - Output: XSA file containing bitstream
        vivado_accelerator: Vivado accelerator workflow (xmutil/dfx-mgr, no extensible kernels)
            - Required: FPGA RTL/IP/constraints files
            - Intermediate: Non-extensible XSA file
            - Output: Bitbin file (.bitbin) and DTBO file (.dtbo)
        vitis_platform: Vitis platform workflow (xmutil/dfx-mgr, extensible kernels)
            - Required: FPGA RTL/IP/constraints files + kernels (Vivado IP and .xo)
            - Intermediate: Extensible XSA file
            - Output: Bitbin file (.xclbin), DTBO file (.dtbo), and JSON file
    
    --vivado-path <path>      Path to Vivado executable (default: C:/AMD/2025.2/Vivado/bin/vivado.bat)
        On Windows, use .bat extension (e.g., vivado.bat)
        On Linux, it typically looks like /opt/Xilinx/Vivado/2025.2/bin/vivado    
    --vivado-path <path>      Path to Vivado executable (default: C:/AMD/2025.2/Vivado/bin/vivado.bat)
    --bootgen-path <path>     Path to Bootgen executable (default: C:/AMD/2025.2/Vivado/bin/bootgen.bat)
    --vitis-path <path>       Path to Vitis executable (default: C:/AMD/2025.2/Vitis/bin/vitis.bat)
    --dtc-path <path>         Path to DTC executable (default: C:/AMD/2025.2/Vitis/bin/dtc.exe)
    --jobs <number>          Parallel jobs for synthesis/implementation (default: 4)
    --reuse <bool>           Reuse existing artifacts if they exist (default: False)

Examples:
    python build_vivado_proj.py                                   # Build complete project (default: all, vitis_standalone flow)
    python build_vivado_proj.py --target vivado                   # Create project and open Vivado GUI
    python build_vivado_proj.py --target bit --jobs 8             # Generate bitstream with 8 parallel jobs
    python build_vivado_proj.py --target bitbin --reuse True      # Generate bitbin only if .bit exists    
    python build_vivado_proj.py --target clean                    # Clean all output directories
    python build_vivado_proj.py --target all --dev-flow vivado    # Build with vivado development flow
    python build_vivado_proj.py --vivado-path C:/AMD/2025.2/Vivado/bin/vivado.bat

Copyright (c) 2024 Juan Manuel Reina
Based on Makefile by Alex Forencich
"""

import os
import sys
import argparse
import subprocess
import shutil
import pathlib
import platform
from typing import List, Dict, Optional
import time

class VivadoBuilder:
    def __init__(self):
        # Project configuration
        self.PROJECT_NAME = "kv260_rpicamera_to_dp"
        self.BD_TOP = "bd_top"
        self.FPGA_PART = "XCK26-SFVC784-2LV-C"
        self.BOARD_PART = "xilinx.com:kv260_som:part0:1.3"
        self.BOARD_CONNECTIONS = "som240_1_connector xilinx.com:kv260_carrier:som240_1_connector:1.3"
        self.SYN_NUM_JOBS = 12
        self.DEV_FLOW = "vitis_standalone"
        self.VIVADO_PATH = "C:/AMD/2025.2/Vivado/bin/vivado.bat"
        self.BOOTGEN_PATH = "C:/AMD/2025.2/Vivado/bin/bootgen.bat"
        self.VITIS_PATH = "C:/AMD/2025.2/Vitis/bin/vitis.bat"
        self.DTC_PATH = "C:/AMD/2025.2/Vitis/bin/dtc.exe"
        self.REUSE = False
        
        # Detect environment and set paths
        self.script_path = pathlib.Path(__file__).resolve()
        self.workspace_path = self.script_path.parent.parent
        
        # Convert to forward slashes for TCL compatibility
        self.workspace_path_str = str(self.workspace_path).replace('\\', '/')
        
        # Output directories
        self.artifacts_path = self.workspace_path / "output" / "artifacts"
        self.vivado_path = self.workspace_path / "output" / "vivado"
        self.dtbo_path = self.workspace_path / "output" / "dtbo"
        self.xpfm_path = self.workspace_path / "output" / "xpfm"
        
        # Source files
        self.src_path = self.workspace_path / "rtl"
        self.src_vhdl_files = [
            self.src_path / "counter_wrapper.vhd",
            self.src_path / "pwm.vhd"
        ]
        self.src_vhdl08_files = [
            self.src_path / "utils_pkg.vhd"
        ]
        self.src_verilog_files = [
            self.src_path / "counter.v"
        ]
        self.inc_verilog_files = [
            self.src_path / "utils.v"
        ]
        
        # Constraints and IPs
        self.xdc_files = [self.workspace_path / "constraints" / "kv260.xdc"]
        self.ip_tcl_files = [self.workspace_path / "ips" / "platform.tcl"]
        
        # Platform and kernel files
        self.pfm_tcl_path = self.workspace_path / "common" / "pfm.tcl"
        self.kernel_name = "my_ip"
        self.kernel_src_path = self.workspace_path / "kernels"
        self.link_input_path = self.workspace_path / "kernels" / "my_ip.xo"
        
        print(f"Workspace path: {self.workspace_path_str}")
        print(f"Development flow: {self.DEV_FLOW}")

    def create_directories(self):
        """Create all necessary output directories"""
        print("Creating output directories...")
        directories = [
            self.artifacts_path,
            self.vivado_path,
            self.dtbo_path,
            self.xpfm_path
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"  Created: {directory}")

    def clean(self):
        """Clean all output directories"""
        print("Cleaning output directories...")
        directories = [
            self.artifacts_path,
            self.vivado_path,
            self.dtbo_path,
            self.xpfm_path
        ]
        
        for directory in directories:
            if directory.exists():
                shutil.rmtree(directory)
                print(f"  Removed: {directory}")
        
        # Clean Vivado temporary files in output directory
        output_dir = self.workspace_path / "output"
        if output_dir.exists():
            patterns = ["vivado*.jou", "vivado*.log", "dfx_runtime.txt"]
            for pattern in patterns:
                for file_path in output_dir.glob(pattern):
                    file_path.unlink()
                    print(f"  Removed: {file_path}")

    def get_tool_path(self, tool_type: str) -> str:
        """Get path for specific tool (vivado, bootgen, xsct)"""
        if tool_type == "vivado":
            return self.VIVADO_PATH if self.VIVADO_PATH else "vivado"
        elif tool_type == "bootgen":
            return self.BOOTGEN_PATH if self.BOOTGEN_PATH else "bootgen"
        elif tool_type == "vitis":
            return self.VITIS_PATH if self.VITIS_PATH else "vitis"
        elif tool_type == "dtc":
            return self.DTC_PATH if self.DTC_PATH else "dtc"
        return tool_type

    def run_vitis_script(self, py_script: str, working_dir: Optional[pathlib.Path] = None) -> bool:
        """Run Vitis with a Python script"""
        vitis_exe = self.get_tool_path("vitis")
        cmd = [vitis_exe, "-s", py_script]
        
        if working_dir:
            original_cwd = os.getcwd()
            os.chdir(working_dir)
        else:
            original_cwd = None
            
        try:
            print(f"Executing Vitis Python Script: {' '.join(cmd)}")
            result = subprocess.run(cmd, text=True)
            return result.returncode == 0
        except FileNotFoundError:
            print("Error: vitis command not found.")
            return False
        finally:
            if original_cwd:
                os.chdir(original_cwd)

    def run_vivado(self, tcl_script: str, working_dir: Optional[pathlib.Path] = None) -> bool:
        """Run Vivado with a TCL script"""
        vivado_exe = self.get_tool_path("vivado")
        cmd = [vivado_exe, "-nojournal", "-nolog", "-mode", "batch", "-source", tcl_script]
        
        if working_dir:
            original_cwd = os.getcwd()
            os.chdir(working_dir)
            print(f"Running Vivado from: {working_dir}")
        else:
            original_cwd = None
        
        try:
            print(f"Executing: {' '.join(cmd)}")
            result = subprocess.run(cmd, text=True)
            
            if result.returncode != 0:
                print(f"Vivado failed with return code {result.returncode}")
                return False
            else:
                print("Vivado completed successfully")
                return True
                
        except FileNotFoundError:
            print("Error: vivado command not found. Make sure Vivado is installed and in PATH.")
            return False
        finally:
            if original_cwd:
                os.chdir(original_cwd)

    def create_project_tcl(self) -> str:
        """Generate TCL script for creating Vivado project"""
        tcl_content = []
        
        # Create project
        tcl_content.append(f"create_project -force -part {self.FPGA_PART} {self.PROJECT_NAME}")
        tcl_content.append(f"set_property board_part {self.BOARD_PART} [current_project]")
        tcl_content.append(f"set_property board_connections {{{self.BOARD_CONNECTIONS}}} [current_project]")
        
        # Add sources
        if self.src_vhdl_files:
            vhdl_files_str = " ".join([str(f).replace('\\', '/') for f in self.src_vhdl_files])
            tcl_content.append(f"read_vhdl {{{vhdl_files_str}}}")
        
        if self.src_vhdl08_files:
            vhdl08_files_str = " ".join([str(f).replace('\\', '/') for f in self.src_vhdl08_files])
            tcl_content.append(f"read_vhdl -vhdl2008 {{{vhdl08_files_str}}}")
        
        if self.src_verilog_files or self.inc_verilog_files:
            verilog_files = self.src_verilog_files + self.inc_verilog_files
            verilog_files_str = " ".join([str(f).replace('\\', '/') for f in verilog_files])
            tcl_content.append(f"read_verilog {{{verilog_files_str}}}")
        
        # Add constraints
        if self.xdc_files:
            xdc_files_str = " ".join([str(f).replace('\\', '/') for f in self.xdc_files])
            tcl_content.append(f"add_files -fileset constrs_1 {{{xdc_files_str}}}")
        
        # Add IP TCL files
        for ip_tcl in self.ip_tcl_files:
            tcl_content.append(f"source {ip_tcl.as_posix().replace('\\', '/')}")
        
        return "\n".join(tcl_content)

    def create_project(self) -> bool:
        """Create Vivado project"""
        xpr_file = self.vivado_path / f"{self.PROJECT_NAME}.xpr"
        if self.REUSE and xpr_file.exists():
            print(f"Reusing existing project: {xpr_file}")
            return True

        print("\n" + "="*60)
        print("Creating Vivado project...")
        print("="*60 + "\n")
        
        # Change to vivado directory
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            # Generate TCL script
            tcl_content = self.create_project_tcl()
            tcl_file = "create_project.tcl"
            
            with open(tcl_file, 'w') as f:
                f.write(tcl_content)
            
            print(f"Generated TCL script: {tcl_file}")
            
            # Run Vivado
            return self.run_vivado(tcl_file)
            
        finally:
            os.chdir(original_cwd)

    def open_vivado_gui(self) -> bool:
        """Open Vivado GUI with the project"""
        print("\nOpening Vivado GUI...")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            xpr_file = self.vivado_path / f"{self.PROJECT_NAME}.xpr"
            if not xpr_file.exists():
                print(f"Error: Project file {xpr_file} not found. Create project first.")
                return False
            
            cmd = [self.get_tool_path("vivado"), str(xpr_file)]
            print(f"Executing: {' '.join(cmd)}")
            
            # For GUI, we don't want to capture output
            result = subprocess.run(cmd)
            return result.returncode == 0
            
        finally:
            os.chdir(original_cwd)

    def run_synthesis(self) -> bool:
        """Run synthesis"""
        # Check for synthesis checkpoint
        dcp_file = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "synth_1" / f"{self.BD_TOP}_wrapper.dcp"
        if self.REUSE and dcp_file.exists():
            print(f"Reusing existing synthesis: {dcp_file}")
            return True

        print("\n" + "="*60)
        print("Running synthesis...")
        print("="*60 + "\n")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            tcl_content = []
            tcl_content.append(f"open_project {self.PROJECT_NAME}.xpr")
            tcl_content.append("reset_run synth_1")
            tcl_content.append(f"launch_runs -jobs {self.SYN_NUM_JOBS} synth_1")
            tcl_content.append("wait_on_run synth_1")
            
            tcl_file = "run_synth.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            return self.run_vivado(tcl_file)
            
        finally:
            os.chdir(original_cwd)

    def run_implementation(self) -> bool:
        """Run implementation"""
        # Check for implementation checkpoint
        dcp_file = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.BD_TOP}_wrapper_routed.dcp"
        if self.REUSE and dcp_file.exists():
            print(f"Reusing existing implementation: {dcp_file}")
            return True

        print("\n" + "="*60)
        print("Running implementation...")
        print("="*60 + "\n")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            tcl_content = []
            tcl_content.append(f"open_project {self.PROJECT_NAME}.xpr")
            tcl_content.append("reset_run impl_1")
            tcl_content.append(f"launch_runs -jobs {self.SYN_NUM_JOBS} impl_1")
            tcl_content.append("wait_on_run impl_1")
            tcl_content.append("open_run impl_1")
            tcl_content.append(f"report_utilization -file {self.PROJECT_NAME}_utilization.rpt")
            tcl_content.append(f"report_utilization -hierarchical -file {self.PROJECT_NAME}_utilization_hierarchical.rpt")
            
            tcl_file = "run_impl.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            return self.run_vivado(tcl_file)
            
        finally:
            os.chdir(original_cwd)

    def generate_bitstream(self) -> bool:
        """Generate bitstream"""
        bit_file = self.artifacts_path / f"{self.PROJECT_NAME}.bit"
        if self.REUSE and bit_file.exists():
            print(f"Reusing existing bitstream: {bit_file}")
            return True

        print("\n" + "="*60)
        print("Generating bitstream...")
        print("="*60 + "\n")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            # Remove existing bitstream to force regeneration
            bit_file = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.PROJECT_NAME}.bit"
            if bit_file.exists():
                bit_file.unlink()
            
            tcl_content = []
            tcl_content.append(f"open_project {self.PROJECT_NAME}.xpr")
            tcl_content.append("open_run impl_1")
            tcl_content.append(f"write_bitstream -force {self.PROJECT_NAME}.runs/impl_1/{self.PROJECT_NAME}.bit")
            tcl_content.append(f"write_debug_probes -force {self.PROJECT_NAME}.runs/impl_1/{self.PROJECT_NAME}.ltx")
            
            tcl_file = "generate_bit.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            success = self.run_vivado(tcl_file)
            
            if success:
                # Create symbolic links/copy to artifacts directory
                bit_source = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.PROJECT_NAME}.bit"
                bit_dest = self.artifacts_path / f"{self.PROJECT_NAME}.bit"
                
                if bit_source.exists():
                    shutil.copy2(bit_source, bit_dest)
                    print(f"Copied bitstream to: {bit_dest}")
                
                # Copy LTX file if it exists
                ltx_source = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.PROJECT_NAME}.ltx"
                ltx_dest = self.artifacts_path / f"{self.PROJECT_NAME}.ltx"
                
                if ltx_source.exists():
                    shutil.copy2(ltx_source, ltx_dest)
                    print(f"Copied LTX file to: {ltx_dest}")
            
            return success
            
        finally:
            os.chdir(original_cwd)

    def generate_xsa_non_extensible(self) -> bool:
        """Generate non-extensible XSA file"""
        xsa_path = self.artifacts_path / f"{self.PROJECT_NAME}.xsa"
        if self.REUSE and xsa_path.exists():
            print(f"Reusing existing XSA: {xsa_path}")
            return True

        print("\n" + "="*60)
        print("Generating non-extensible XSA file...")
        print("="*60 + "\n")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            # Copy bitstream with expected name
            bit_source = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.PROJECT_NAME}.bit"
            bit_dest = self.vivado_path / f"{self.PROJECT_NAME}.runs" / "impl_1" / f"{self.BD_TOP}_wrapper.bit"
            
            if bit_source.exists():
                shutil.copy2(bit_source, bit_dest)
            
            tcl_content = []
            tcl_content.append(f"open_project {self.PROJECT_NAME}.xpr")
            xsa_path = self.artifacts_path / f"{self.PROJECT_NAME}.xsa"
            tcl_content.append(f"write_hw_platform -fixed -include_bit -force -file {xsa_path.as_posix().replace('\\', '/')}")
            
            tcl_file = "generate_xsa.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            success = self.run_vivado(tcl_file)
            
            if success and xsa_path.exists():
                print(f"Generated XSA: {xsa_path}")
                # Create marker file
                marker_file = self.artifacts_path / "xsa_non_ext"
                marker_file.touch()
            
            return success
            
        finally:
            os.chdir(original_cwd)

    def generate_xsa_extensible(self) -> bool:
        """Generate extensible XSA file"""
        print("\n" + "="*60)
        print("Generating extensible XSA file...")
        print("="*60 + "\n")
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            tcl_content = []
            tcl_content.append(f"open_project {self.PROJECT_NAME}.xpr")
            
            # Generate output products for block design
            tcl_content.append(f"delete_ip_run [get_files -of_objects [get_fileset sources_1] {self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd]")
            tcl_content.append(f"set_property synth_checkpoint_mode None [get_files {self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd]")
            tcl_content.append(f"generate_target all [get_files {self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd]")
            
            # Export IP user files
            tcl_content.append(f"export_ip_user_files -of_objects [get_files {self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd] -no_script -sync -force -quiet")
            tcl_content.append(f"export_simulation -of_objects [get_files {self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd] -directory {self.PROJECT_NAME}.ip_user_files/sim_scripts -ip_user_files_dir {self.PROJECT_NAME}.ip_user_files -ipstatic_source_dir {self.PROJECT_NAME}.ip_user_files/ipstatic -lib_map_path [list {{modelsim={self.PROJECT_NAME}.cache/compile_simlib/modelsim}} {{questa={self.PROJECT_NAME}.cache/compile_simlib/questa}} {{xcelium={self.PROJECT_NAME}.cache/compile_simlib/xcelium}} {{vcs={self.PROJECT_NAME}.cache/compile_simlib/vcs}} {{riviera={self.PROJECT_NAME}.cache/compile_simlib/riviera}}] -use_ip_compiled_libs -force -quiet")
            
            # Configure platform properties
            tcl_content.append("set_property platform.board_id {board} [current_project]")
            tcl_content.append("set_property platform.name {name} [current_project]")
            tcl_content.append(f"set_property pfm_name {{xilinx:board:name:0.0}} [get_files -all {{{self.PROJECT_NAME}.srcs/sources_1/bd/{self.BD_TOP}/{self.BD_TOP}.bd}}]")
            tcl_content.append("set_property platform.extensible {true} [current_project]")
            tcl_content.append("set_property platform.design_intent.embedded {true} [current_project]")
            tcl_content.append("set_property platform.design_intent.datacenter {false} [current_project]")
            tcl_content.append("set_property platform.design_intent.server_managed {false} [current_project]")
            tcl_content.append("set_property platform.design_intent.external_host {false} [current_project]")
            tcl_content.append("set_property platform.default_output_type {sd_card} [current_project]")
            tcl_content.append("set_property platform.uses_pr {false} [current_project]")
            
            # Write XSA
            xsa_path = self.artifacts_path / f"{self.PROJECT_NAME}.xsa"
            tcl_content.append(f"write_hw_platform -hw -force -file {xsa_path.as_posix().replace('\\', '/')}")
            
            tcl_file = "generate_xsa.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            success = self.run_vivado(tcl_file)
            
            if success and xsa_path.exists():
                print(f"Generated extensible XSA: {xsa_path}")
                # Create marker file
                marker_file = self.artifacts_path / "xsa_ext"
                marker_file.touch()
            
            return success
            
        finally:
            os.chdir(original_cwd)

    def generate_bitbin(self) -> bool:
        """Generate bitbin file"""
        bitbin_file = self.artifacts_path / f"{self.PROJECT_NAME}.bitbin"
        if self.REUSE and bitbin_file.exists():
            print(f"Reusing existing bitbin: {bitbin_file}")
            return True

        print("\n" + "="*60)
        print("Generating bitbin file...")
        print("="*60 + "\n")
        
        bit_file = self.artifacts_path / f"{self.PROJECT_NAME}.bit"
        if not bit_file.exists():
            print(f"Error: Bit file {bit_file} not found. Generate bitstream first.")
            return False
        
        original_cwd = os.getcwd()
        os.chdir(self.artifacts_path)
        
        try:
            # Create BIF file
            bif_content = f"all:{{{self.PROJECT_NAME}.bit}}"
            with open("bootgen.bif", 'w') as f:
                f.write(bif_content)
            
            # Run bootgen
            bootgen_exe = self.get_tool_path("bootgen")
            cmd = [bootgen_exe, "-w", "-arch", "zynqmp", "-process_bitstream", "bin", "-image", "bootgen.bif"]
            print(f"Executing: {' '.join(cmd)}")
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"Bootgen failed: {result.stderr}")
                return False
            else:
                bitbin_file = self.artifacts_path / f"{self.PROJECT_NAME}.bitbin"
                print(f"Generated bitbin: {bitbin_file}")
                return True
                
        except FileNotFoundError:
            print("Error: bootgen command not found. Make sure Xilinx tools are installed and in PATH.")
            return False
        finally:
            os.chdir(original_cwd)

    def program_fpga(self) -> bool:
        """Program the FPGA"""
        print("\n" + "="*60)
        print("Programming FPGA...")
        print("="*60 + "\n")
        
        bit_file = self.artifacts_path / f"{self.PROJECT_NAME}.bit"
        if not bit_file.exists():
            print(f"Error: Bit file {bit_file} not found. Generate bitstream first.")
            return False
        
        original_cwd = os.getcwd()
        os.chdir(self.vivado_path)
        
        try:
            tcl_content = []
            tcl_content.append("open_hw_manager")
            tcl_content.append("connect_hw_server")
            tcl_content.append("open_hw_target")
            tcl_content.append("current_hw_device [lindex [get_hw_devices] 0]")
            tcl_content.append("refresh_hw_device -update_hw_probes false [current_hw_device]")
            tcl_content.append(f"set_property PROGRAM.FILE {{{bit_file.as_posix().replace('\\', '/')}}} [current_hw_device]")
            tcl_content.append("program_hw_devices [current_hw_device]")
            tcl_content.append("exit")
            
            tcl_file = "program.tcl"
            with open(tcl_file, 'w') as f:
                f.write("\n".join(tcl_content))
            
            return self.run_vivado(tcl_file)
            
        finally:
            os.chdir(original_cwd)

    def generate_dtbo(self) -> bool:
        """Generate Device Tree Overlay (DTBO)"""
        dtbo_out = self.artifacts_path / f"{self.PROJECT_NAME}.dtbo"
        if self.REUSE and dtbo_out.exists():
            print(f"Reusing existing DTBO: {dtbo_out}")
            return True

        print("\n" + "="*60)
        print("Generating DTBO...")
        print("="*60 + "\n")
        
        xsa_path = self.artifacts_path / f"{self.PROJECT_NAME}.xsa"
        if not xsa_path.exists():
            print("Error: XSA not found for DTBO generation.")
            return False
            
        original_cwd = os.getcwd()
        
        # If we are here, we NEED to generate the DTBO. 
        # To avoid version mismatch errors, we ensure the vitis workspace is clean.
        vitis_ws = self.dtbo_path / "vitis_ws"
        if vitis_ws.exists():
            print(f"Cleaning existing Vitis workspace metadata: {vitis_ws}")
            shutil.rmtree(vitis_ws)
        
        self.dtbo_path.mkdir(parents=True, exist_ok=True)
        os.chdir(self.dtbo_path)
        
        try:
            # 1. Generate Vitis Python script for Platform/DTB generation
            py_script_content = [
                "import vitis",
                "import os",
                "import shutil",
                f"workspace = '{vitis_ws.as_posix()}'",
                "os.makedirs(workspace, exist_ok=True)",
                "client = vitis.create_client()",
                "try:",
                "    client.set_workspace(workspace)",
                "except Exception:",
                "    client.dispose()",
                "    shutil.rmtree(os.path.join(workspace, '.vitis'), ignore_errors=True)",
                "    client = vitis.create_client()",
                "    client.set_workspace(workspace)",
                "",
                "platform_name = 'p'",  # Very short to avoid MAX_PATH
                "hw_design = '" + xsa_path.as_posix() + "'",
                "",
                "print(f'Creating platform component from {hw_design}...')",
                "platform = client.create_platform_component(",
                "    name=platform_name,",
                "    hw_design=hw_design,",
                "    os='linux',",
                "    cpu='psu_cortexa53_0',",
                "    domain_name='d',",
                "    generate_dtb=True",
                ")",
                "",
                "print('Adding overlay domain...')",
                "platform.add_domain(",
                "    cpu='psu_cortexa53_0',",
                "    os='linux',",
                "    name='ovl',",
                "    generate_dtb=True,",
                "    dt_overlay=True",
                ")",
                "",
                "print('Building platform (DTB/DTBO generation)...')",
                "try:",
                "    platform.build()",
                "except Exception as e:",
                "    print(f'Build warning/error: {e}')",
                "    print('Proceeding to check if DTSI/DTBO was generated anyway...')",
                "vitis.dispose()"
            ]
            
            py_script = "build_platform.py"
            with open(py_script, 'w') as f:
                f.write("\n".join(py_script_content))
            
            if not self.run_vitis_script(py_script):
                return False
                
            # 2. Locate the generated DTSI and prepare artifact for editing
            platform_dir = self.dtbo_path / "vitis_ws" / "p"
            found_dtsis = list(platform_dir.glob("**/pl.dtsi")) + list(platform_dir.glob("**/system-top.dtsi"))
            
            if not found_dtsis:
                print("Error: Could not find generated DTSI file.")
                return False
                
            src_dtsi = found_dtsis[0]
            dtsi_artifact = self.artifacts_path / f"{self.PROJECT_NAME}.dtsi"
            
            # Copy to artifacts immediately so user can edit a persistent file
            shutil.copy2(src_dtsi, dtsi_artifact)
            
            print("\n" + "*"*80)
            print(f" DEVICE TREE SOURCE READY FOR EDITING AT:")
            print(f" {dtsi_artifact}")
            print("*"*80)
            print(" ACTION REQUIRED:")
            print(" 1. Open the file ABOVE in your editor (the one in artifacts).")
            print(" 2. Add the V4L2/Media Graph fragments from 'plan_port_v4l2.md'.")
            print(" 3. Save the file.")
            print("*"*80)
            input(" Press Enter once you have finished editing to continue with compilation...")
            
            # 3. Manually compile the artifact version
            print(f"Compiling edited DTSI from artifacts: {dtsi_artifact}")
            dtc_exe = self.get_tool_path("dtc")
            dtbo_out = self.artifacts_path / f"{self.PROJECT_NAME}.dtbo"
            cmd = [dtc_exe, "-@", "-O", "dtb", "-o", str(dtbo_out), str(dtsi_artifact)]
            
            subprocess.run(cmd, check=True)
            print(f"Successfully generated manually edited DTBO at: {dtbo_out}")
                
            return True
            
        except Exception as e:
            print(f"DTBO generation failed: {e}")
            return False
        finally:
            os.chdir(original_cwd)

    def copy_shell_json(self) -> bool:
        """Copy shell.json to artifacts"""
        shell_src = self.workspace_path / "common" / "shell.json"
        shell_dest = self.artifacts_path / "shell.json"
        if shell_src.exists():
            shutil.copy2(shell_src, shell_dest)
            print(f"Copied shell.json to {shell_dest}")
            return True
        return False

    def generate_xclbin(self) -> bool:
        """Generate xclbin for vitis_platform flow"""
        print("\n" + "="*60)
        print("Generating extensible platform (XPFM)...")
        print("="*60 + "\n")
        
        xsa_path = self.artifacts_path / f"{self.PROJECT_NAME}.xsa"
        if not xsa_path.exists():
            print("Error: Extensible XSA not found.")
            return False

        original_cwd = os.getcwd()
        
        # Ensure clean vitis workspace for XPFM
        vitis_ws = self.xpfm_path / "vitis_ws"
        if vitis_ws.exists():
            print(f"Cleaning existing XPFM Vitis workspace metadata: {vitis_ws}")
            shutil.rmtree(vitis_ws)
            
        self.xpfm_path.mkdir(parents=True, exist_ok=True)
        os.chdir(self.xpfm_path)

        # 1. Generate extensible platform using Vitis Python API
        py_script_content = [
            "import vitis",
            "import os",
            "import shutil",
            f"workspace = '{vitis_ws.as_posix()}'",
            "os.makedirs(workspace, exist_ok=True)",
            "client = vitis.create_client()",
            "try:",
            "    client.set_workspace(workspace)",
            "except Exception as e:",
            "    if 'version' in str(e).lower() or 'metadata' in str(e).lower():",
            "        client.dispose()",
            "        metadata_folder = os.path.join(workspace, '.vitis')",
            "        if os.path.exists(metadata_folder): shutil.rmtree(metadata_folder)",
            "        client = vitis.create_client()",
            "        client.set_workspace(workspace)",
            "    else:",
            "        raise",
            f"hw_design = '{xsa_path.as_posix()}'",
            f"platform_name = '{self.PROJECT_NAME}_ext_plt'",
            "",
            "print(f'Creating extensible platform {platform_name}...')",
            "try:",
            "    client.get_component(name=platform_name)",
            "    platform = client.get_component(name=platform_name)",
            "except Exception:",
            "    platform = client.create_platform_component(",
            "        name=platform_name,",
            "        hw_design=hw_design,",
            "        os='linux',",
            "        cpu='psu_cortexa53_0'",
            "    )",
            "",
            "print('Building platform...')",
            "platform.build()",
            "",
            "xpfm_path = client.find_platform_in_repos(platform_name)",
            "print(f'XPFM_GENERATED_AT:{xpfm_path}')",
            "vitis.dispose()"
        ]
        
        py_script = "gen_xpfm.py"
        with open(self.xpfm_path / py_script, 'w') as f:
            f.write("\n".join(py_script_content))
            
        if not self.run_vitis_script(str(self.xpfm_path / py_script)):
            return False
            
        # 2. Run v++ (placeholder for user to implement specific kernel linking)
        print("Warning: Skipping v++ linking. User must define kernel link step using the generated XPFM.")
        return True

    def build_target(self, target: str, _directories_created: bool = False) -> bool:
        """Build a specific target"""
        print(f"Building target: {target}")
        
        if target == "clean":
            self.clean()
            return True
        
        # Create directories for all other targets (only once)
        if not _directories_created:
            self.create_directories()
        
        if target == "vivado":
            # Create project first, then open GUI
            if not self.create_project():
                return False
            return self.open_vivado_gui()
        
        elif target == "bit":
            # Create project, run synthesis, implementation, and generate bitstream
            if not self.create_project():
                return False
            if not self.run_synthesis():
                return False
            if not self.run_implementation():
                return False
            return self.generate_bitstream()
        
        elif target == "xsa_non_extensible":
            # Need bitstream first
            if not self.build_target("bit", _directories_created=True):
                return False
            return self.generate_xsa_non_extensible()
        
        elif target == "xsa_extensible":
            # Need project created first
            return self.generate_xsa_extensible()
        
        elif target == "bitbin":
            # Need bitstream first
            if not self.build_target("bit", _directories_created=True):
                return False
            return self.generate_bitbin()
        
        elif target == "program":
            return self.program_fpga()
        
        elif target == "all":
            # Build based on development flow
            if self.DEV_FLOW == "vivado":
                return self.build_target("bit", _directories_created=True)
            elif self.DEV_FLOW == "vitis_standalone":
                return self.build_target("xsa_non_extensible", _directories_created=True)
            elif self.DEV_FLOW == "vivado_accelerator":
                if not self.build_target("bitbin", _directories_created=True): return False
                if not self.build_target("xsa_non_extensible", _directories_created=True): return False
                if not self.build_target("dtbo", _directories_created=True): return False
                return self.copy_shell_json()
            elif self.DEV_FLOW == "vitis_platform":
                if not self.build_target("xsa_extensible", _directories_created=True): return False
                if not self.build_target("dtbo", _directories_created=True): return False
                if not self.generate_xclbin(): return False
                return self.copy_shell_json()
            else:
                print(f"Error: Unsupported development flow: {self.DEV_FLOW}")
                return False
        
        elif target == "dtbo":
            return self.generate_dtbo()

        elif target == "xclbin":
            return self.generate_xclbin()
        
        else:
            print(f"Error: Unknown target: {target}")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Vivado/Vitis Build Script - Python equivalent of Makefile",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        "--target",
        default="all",
        choices=["all", "vivado", "bit", "xsa_non_extensible", "xsa_extensible", 
                "bitbin", "dtbo", "xclbin", "program", "clean"],
        help="Build target to execute (default: all)"
    )
    
    parser.add_argument(
        "--dev-flow",
        choices=["vivado", "vitis_standalone", "vivado_accelerator", "vitis_platform"],
        default="vitis_standalone",
        help="Development flow (default: vitis_standalone)"
    )
    
    parser.add_argument(
        "--vivado-path",
        default="C:/AMD/2025.2/Vivado/bin/vivado.bat",
        help="Path to Vivado executable (default: C:/AMD/2025.2/Vivado/bin/vivado.bat)"
    )

    parser.add_argument(
        "--bootgen-path",
        default="C:/AMD/2025.2/Vivado/bin/bootgen.bat",
        help="Path to Bootgen executable"
    )

    parser.add_argument(
        "--vitis-path",
        default="C:/AMD/2025.2/Vitis/bin/vitis.bat",
        help="Path to Vitis executable"
    )

    parser.add_argument(
        "--dtc-path",
        default="C:/AMD/2025.2/Vitis/bin/dtc.exe",
        help="Path to DTC executable"
    )
    
    parser.add_argument(
        "--jobs",
        type=int,
        default=4,
        help="Number of parallel jobs for synthesis/implementation (default: 4)"
    )

    parser.add_argument(
        "--reuse",
        type=lambda x: (str(x).lower() in ['true', '1', 'yes']),
        default=False,
        help="Reuse existing artifacts if they exist (default: False)"
    )
    
    args = parser.parse_args()
    
    # Create builder
    builder = VivadoBuilder()
    
    # Override settings from command line
    builder.DEV_FLOW = args.dev_flow
    builder.SYN_NUM_JOBS = args.jobs
    builder.VIVADO_PATH = args.vivado_path
    builder.BOOTGEN_PATH = args.bootgen_path
    builder.VITIS_PATH = args.vitis_path
    builder.DTC_PATH = args.dtc_path
    builder.REUSE = args.reuse
    
    print(f"Python Vivado Builder")
    print(f"Target: {args.target}")
    print(f"Development Flow: {builder.DEV_FLOW}")
    print(f"Parallel Jobs: {builder.SYN_NUM_JOBS}")
    print(f"Reuse artifacts: {builder.REUSE}")
    print()
    
    # Build the target
    start_time = time.time()
    success = builder.build_target(args.target)
    end_time = time.time()
    
    print()
    print("="*60)
    if success:
        if args.target == "clean":
            print(f"CLEAN SUCCESSFUL - Completed in {end_time - start_time:.1f} seconds")
        else:
            print(f"BUILD SUCCESSFUL - Completed in {end_time - start_time:.1f} seconds")
    else:
        if args.target == "clean":
            print(f"CLEAN FAILED - Completed in {end_time - start_time:.1f} seconds")
        else:
            print(f"BUILD FAILED - Completed in {end_time - start_time:.1f} seconds")
    print("="*60)
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
