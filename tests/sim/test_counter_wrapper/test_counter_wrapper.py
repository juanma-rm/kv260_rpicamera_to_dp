###################################################################################
# Usage
###################################################################################

# See README.txt

###################################################################################
# Imports
###################################################################################

# General
import logging
import os
import cocotb
import cocotb_test.simulator
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.handle import Release, Force

# Network
from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP
from cocotbext.eth import XgmiiFrame, XgmiiSource, XgmiiSink

# AXI
from cocotbext.axi import AxiBus, AxiRam, AxiLiteMaster, AxiLiteBus

###################################################################################
# TB class (common for all tests)
###################################################################################

class TB:

    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    async def init(self):
        # Reset
        self.dut.rst_i.value = 0
        for _ in range(10): await RisingEdge(self.dut.clk_i)
        self.dut.rst_i.value = 1
        for _ in range(10): await RisingEdge(self.dut.clk_i)
        self.dut.rst_i.value = 0

###################################################################################
# Test: run_test 
# Stimulus: -
# Expected:
# - p_mod outputs 8 most significative bits of count
# - p_mod set to 0 during reset
###################################################################################

@cocotb.test()
async def run_test_counter_wrapper(dut):

    # Initialize TB
    tb = TB(dut)
    await tb.init()
    
    # Leave some extra time to make visual simulation look better
    for _ in range(20): await RisingEdge(dut.clk_i)
    
###################################################################################
# cocotb-test flow (alternative to Makefile flow)
###################################################################################

tests_path = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_path, '..', '..', '..', 'rtl'))

def test_counter_wrapper(request):
    dut = "counter_wrapper"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    vhdl_sources = [
        os.path.join(rtl_dir, "utils_pkg.vhd"),
        os.path.join(rtl_dir, f"{dut}.vhd"),
    ]

    verilog_sources = [
        os.path.join(rtl_dir, "counter.v"),
        os.path.join(rtl_dir, "utils.v"),
    ]
    
    verilog_include_dirs = [
        rtl_dir,
    ]
    
    parameters = {}
    # parameters['A'] = "value"
    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}
    
    plus_args = ["-t", "1ps"]
    # plus_args['-t'] = "1ps"

    sim_build = os.path.join(tests_path, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_path],
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        includes=verilog_include_dirs,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
        plus_args=plus_args,
    )
