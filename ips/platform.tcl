##############################################################################
# Top block design to wrap ZUS+ block, reset, interrupts, user logic, etc.
# 
# It expects to be sourced from within the folder that contains the Vivado project
##############################################################################

##############################################################################
# General parameters
##############################################################################

set PL0_CLK_FREQ_MHZ 100
set PROJECT_NAME kv260_rpicamera_to_dp
set BD_TOP bd_top
set EXTENSIBLE_PLATFORM true

# Select FAN_CONTROL value among the following options
set fan_control_type {ttc0_linux counter_fpga default}
set FAN_CONTROL "ttc0_linux"

##############################################################################
# Main block design based on ZUS+ MPSoC
##############################################################################

# Create block diagram top
create_bd_design "$BD_TOP"
update_compile_order -fileset sources_1

# Zynq Ultrscale+ MPSoC block (default preset)
set zynq_ultra_ps [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps ]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  $zynq_ultra_ps
set_property -dict [ list \
    CONFIG.PSU__USE__M_AXI_GP0 {1}                               \
    CONFIG.PSU__USE__M_AXI_GP1 {0}                               \
    CONFIG.PSU__USE__M_AXI_GP2 {0}                               \
    CONFIG.PSU__USE__S_AXI_GP0 {0}                               \
    CONFIG.PSU__USE__S_AXI_GP2 {1}                               \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $PL0_CLK_FREQ_MHZ \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1}                     \
    CONFIG.PSU__TTC0__WAVEOUT__ENABLE {1}                        \
    CONFIG.PSU__TTC0__WAVEOUT__IO {EMIO}                         \
    CONFIG.PSU__USE__VIDEO {0}                                   \
] $zynq_ultra_ps

##############################################################################
# Clocking Wizard block
##############################################################################

set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
set_property -dict [ list \
    CONFIG.CLKOUT1_DRIVES {Buffer} \
    CONFIG.CLKOUT1_JITTER {115.831} \
    CONFIG.CLKOUT1_PHASE_ERROR {87.180} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT2_JITTER {94.862} \
    CONFIG.CLKOUT2_PHASE_ERROR {87.180} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {300.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLK_OUT3_PORT {clk_200M} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT3_JITTER {102.086} \
    CONFIG.CLKOUT3_PHASE_ERROR {87.180} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.CLK_OUT1_PORT {clk_100M} \
    CONFIG.CLK_OUT2_PORT {clk_300M} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {12.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {4} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {6} \
    CONFIG.MMCM_COMPENSATION {AUTO} \
    CONFIG.NUM_OUT_CLKS {3} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIMITIVE {Auto} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
] [get_bd_cells clk_wiz_0]

##############################################################################
# Reset blocks
##############################################################################

set ps_reset_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ps_reset_100M ]
set ps_reset_200M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ps_reset_200M ]
set ps_reset_300M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ps_reset_300M ]

##############################################################################
# Interrupts (xlconcat)
##############################################################################

set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
set_property -dict [ list \
    CONFIG.NUM_PORTS {3} \
] $xlconcat_0

##############################################################################
# AXI Interconnects
##############################################################################

set axi_interc_hpm0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_interc_hpm0 ]
set_property -dict [ list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {4} \
] $axi_interc_hpm0

set axi_interc_hp0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_interc_hp0 ]
set_property -dict [ list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {1} \
] $axi_interc_hp0

##############################################################################
# Fan control
##############################################################################

if {$FAN_CONTROL eq "ttc0_linux"} {
    # Fan control from PS TTC0 EMIO waveout
    # Add slice IP and configure to take bit 2 from a 3-bit wide input
    set xlslice_fan [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_fan ]
    set_property    CONFIG.DIN_TO {2}                       $xlslice_fan
    set_property    CONFIG.DIN_FROM {2}                     $xlslice_fan
    set_property    CONFIG.DIN_WIDTH {3}                    $xlslice_fan
    set_property    CONFIG.DOUT_WIDTH {1}                   $xlslice_fan
} elseif {$FAN_CONTROL eq "counter_fpga"} {
    # Fan control from FPGA pwm module
    set pwm [ create_bd_cell -type module -reference pwm pwm_inst ]
    # fan_en_b works with negative logic, for what a not gate is used
    create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0
    set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells util_vector_logic_0]
    # duty_cycle_in driven by 7-bit constant set at 20 (duty cycle = 20%)
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
    set_property -dict [list CONFIG.CONST_WIDTH {7} CONFIG.CONST_VAL {20}] [get_bd_cells xlconstant_0]
} elseif {[lsearch -exact $fan_control_type $FAN_CONTROL] == -1} {
    puts "Error: FAN_CONTROL must be one of {ttc0_linux counter_fpga default}"
    exit 1
}

##############################################################################
# counter_wrapper
##############################################################################

set counter_wrapper [ create_bd_cell -type module -reference counter_wrapper counter_wrapper_inst ]

##############################################################################
# Video: MIPI RX + VDMA
##############################################################################

# Raspberry PI I2C + AXI_IIC IP
set som240_1_connector_hda_iic_switch [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 som240_1_connector_hda_iic_switch ]
set axi_iic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_0 ]
set_property -dict [ list \
    CONFIG.IIC_BOARD_INTERFACE {som240_1_connector_hda_iic_switch} \
    CONFIG.IIC_FREQ_KHZ {400} \
    CONFIG.USE_BOARD_FLOW {true} \
] $axi_iic_0

# Raspberry PI MIPI CSI interface
set som240_1_connector_mipi_csi_raspi [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 som240_1_connector_mipi_csi_raspi ]

# RPI enable + constant (1)
set rpi_cam_en [ create_bd_port -dir O -from 0 -to 0 rpi_cam_en ]
set constant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_1 ]
set_property -dict [list \
    CONFIG.CONST_WIDTH {1} \
    CONFIG.CONST_VAL {1} \
] [get_bd_cells constant_1]

# MIPI CSI2 RX
set mipi_csi2_rx_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:5.1 mipi_csi2_rx_0 ]
set_property -dict [ list \
    CONFIG.CMN_NUM_PIXELS {2} \
    CONFIG.DPHYRX_BOARD_INTERFACE {som240_1_connector_mipi_csi_raspi} \
    CONFIG.SupportLevel {1} \
    CONFIG.USE_BOARD_FLOW {true} \
] $mipi_csi2_rx_0

# AXI VDMA
set axi_vdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0 ]
set_property -dict [ list \
    CONFIG.c_s2mm_linebuffer_depth {2048} \
    CONFIG.c_s2mm_max_burst_length {128} \
] $axi_vdma_0

##############################################################################
# Connections
##############################################################################

save_bd_design [current_bd_design]

set pl_clk0 [get_bd_pins $zynq_ultra_ps/pl_clk0]
set pl_resetn0 [get_bd_pins $zynq_ultra_ps/pl_resetn0]

# clk_wiz_0
connect_bd_net $pl_clk0 [get_bd_pins clk_wiz_0/clk_in1] 
set clk_100M [get_bd_pins clk_wiz_0/clk_100M]
set clk_200M [get_bd_pins clk_wiz_0/clk_200M]
set clk_300M [get_bd_pins clk_wiz_0/clk_300M]

# ps_reset_100M
set rst_100M [get_bd_pins ps_reset_100M/peripheral_reset]
set rstn_100M [get_bd_pins ps_reset_100M/peripheral_aresetn]
connect_bd_net [get_bd_pins ps_reset_100M/slowest_sync_clk] $clk_100M
connect_bd_net $pl_resetn0 [get_bd_pins ps_reset_100M/ext_reset_in]

# ps_reset_200M
set rst_200M [get_bd_pins ps_reset_200M/peripheral_reset]
set rstn_200M [get_bd_pins ps_reset_200M/peripheral_aresetn]
connect_bd_net [get_bd_pins ps_reset_200M/slowest_sync_clk] $clk_200M
connect_bd_net $pl_resetn0 [get_bd_pins ps_reset_200M/ext_reset_in]

# ps_reset_300M
set rst_300M [get_bd_pins ps_reset_300M/peripheral_reset]
set rstn_300M [get_bd_pins ps_reset_300M/peripheral_aresetn]
connect_bd_net [get_bd_pins ps_reset_300M/slowest_sync_clk] $clk_300M
connect_bd_net $pl_resetn0 [get_bd_pins ps_reset_300M/ext_reset_in]

# zynq ultrascale
connect_bd_net $clk_300M [get_bd_pins zynq_ultra_ps/maxihpm0_fpd_aclk]
connect_bd_net $clk_300M [get_bd_pins zynq_ultra_ps/saxihp0_fpd_aclk]

# axi_interc_hp0
connect_bd_net [get_bd_pins axi_interc_hp0/aclk] $clk_300M
connect_bd_net [get_bd_pins axi_interc_hp0/aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps/S_AXI_HP0_FPD] [get_bd_intf_pins axi_interc_hp0/M00_AXI]

# axi_interc_hpm0
connect_bd_net [get_bd_pins axi_interc_hpm0/aclk] $clk_300M
connect_bd_net [get_bd_pins axi_interc_hpm0/aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins axi_interc_hpm0/S00_AXI] [get_bd_intf_pins zynq_ultra_ps/M_AXI_HPM0_FPD]

# Interrupts
connect_bd_net [get_bd_pins axi_intc_0/s_axi_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_intc_0/s_axi_aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins axi_interc_hpm0/M01_AXI]
connect_bd_net [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps/pl_ps_irq0]
connect_bd_net [get_bd_pins axi_intc_0/intr] [get_bd_pins xlconcat_0/dout] 

# RPI I2C
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aresetn] $rstn_300M
connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In2]
connect_bd_intf_net -intf_net axi_iic_0_IIC [get_bd_intf_pins axi_iic_0/IIC] [get_bd_intf_ports som240_1_connector_hda_iic_switch]
connect_bd_intf_net [get_bd_intf_pins axi_iic_0/S_AXI] [get_bd_intf_pins axi_interc_hpm0/M03_AXI]

# RPI enable set to 1
connect_bd_net [get_bd_ports rpi_cam_en] [get_bd_pins constant_1/dout]

# MIPI CSI RX
connect_bd_net [get_bd_pins mipi_csi2_rx_0/lite_aclk] $clk_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/lite_aresetn] $rstn_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/dphy_clk_200M] $clk_200M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/video_aclk] $clk_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/video_aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_0/video_out] [get_bd_intf_pins axi_vdma_0/S_AXIS_S2MM] 
connect_bd_intf_net -intf_net som240_1_connector_mipi_csi_raspi_1 [get_bd_intf_pins mipi_csi2_rx_0/mipi_phy_if] [get_bd_intf_ports som240_1_connector_mipi_csi_raspi]
connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_0/csirxss_s_axi] [get_bd_intf_pins axi_interc_hpm0/M02_AXI]

# AXI VDMA
connect_bd_net [get_bd_pins axi_vdma_0/s_axi_lite_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_vdma_0/m_axi_mm2s_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_vdma_0/m_axis_mm2s_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_vdma_0/m_axi_s2mm_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_vdma_0/s_axis_s2mm_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_vdma_0/axi_resetn] $rstn_300M
connect_bd_net [get_bd_pins axi_vdma_0/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_vdma_0/s2mm_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_intf_net [get_bd_intf_pins axi_vdma_0/S_AXI_LITE] [get_bd_intf_pins axi_interc_hpm0/M00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_vdma_0/M_AXI_MM2S] [get_bd_intf_pins axi_interc_hp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_vdma_0/M_AXI_S2MM] [get_bd_intf_pins axi_interc_hp0/S01_AXI]

# counter_wrapper
create_bd_port -dir O -from 7 -to 0 pmod
connect_bd_net [get_bd_pins counter_wrapper_inst/clk_i]  $clk_100M
connect_bd_net [get_bd_pins counter_wrapper_inst/rst_i]  $rst_100M
connect_bd_net [get_bd_pins counter_wrapper_inst/pmod_o] [get_bd_ports pmod] 

# Fan control
if {$FAN_CONTROL eq "ttc0_linux"} {
    create_bd_port -dir O -from 0 -to 0 fan_en_b
    connect_bd_net [get_bd_pins /xlslice_fan/Dout] [get_bd_ports fan_en_b]
    connect_bd_net [get_bd_pins $zynq_ultra_ps/emio_ttc0_wave_o] [get_bd_pins xlslice_fan/Din]
} elseif {$FAN_CONTROL eq "counter_fpga"} {
    connect_bd_net [get_bd_pins pwm_inst/clk_i]  $clk_100M
    connect_bd_net [get_bd_pins pwm_inst/rst_i]  $rst_100M
    create_bd_port -dir O -from 0 -to 0 fan_en_b
    connect_bd_net [get_bd_pins pwm_inst/pwm_o] [get_bd_pins util_vector_logic_0/Op1]
    connect_bd_net [get_bd_ports fan_en_b]      [get_bd_pins util_vector_logic_0/Res]
    connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins pwm_inst/duty_cycle_in]
} elseif {[lsearch -exact $fan_control_type $FAN_CONTROL] == -1} {
    puts "Error: FAN_CONTROL must be one of {ttc0_linux counter_fpga default}"
    exit 1
}

##############################################################################
# AXI address mapping
##############################################################################

save_bd_design [current_bd_design]

# AXI VDMA MM2S memory map: how it sees PS
assign_bd_address -target_address_space /axi_vdma_0/Data_MM2S [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_DDR_LOW] -force
assign_bd_address -target_address_space /axi_vdma_0/Data_MM2S [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_QSPI] -force
assign_bd_address -target_address_space /axi_vdma_0/Data_MM2S [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_LPS_OCM] -force
exclude_bd_addr_seg [get_bd_addr_segs axi_vdma_0/Data_MM2S/SEG_zynq_ultra_ps_HP0_DDR_HIGH]

# AXI VDMA S2MM memory map: how it sees PS
assign_bd_address -target_address_space /axi_vdma_0/Data_S2MM [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_DDR_LOW] -force
assign_bd_address -target_address_space /axi_vdma_0/Data_S2MM [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_QSPI] -force
assign_bd_address -target_address_space /axi_vdma_0/Data_S2MM [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_LPS_OCM] -force
exclude_bd_addr_seg [get_bd_addr_segs axi_vdma_0/Data_S2MM/SEG_zynq_ultra_ps_HP0_DDR_HIGH]

# PS memory map: how it sees interrupt controller
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force

# PS memory map: how it sees AXI VDMA S_AXI_LITE
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs axi_vdma_0/S_AXI_LITE/Reg] -force

# PS memory map: how it sees MIPI CSI RX AXI
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs mipi_csi2_rx_0/csirxss_s_axi/Reg] -force

# PS memory map: how it sees AXI IIC
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs axi_iic_0/S_AXI/Reg] -force

##############################################################################
# Regenerate layout and validate design
##############################################################################

regenerate_bd_layout
update_compile_order -fileset sources_1
save_bd_design [current_bd_design]

validate_bd_design
save_bd_design [current_bd_design]

##############################################################################
# Make wrapper around bd and set bd_top_wrapper as top
##############################################################################

make_wrapper -files [get_files $PROJECT_NAME.srcs/sources_1/bd/$BD_TOP/$BD_TOP.bd] -top
add_files -norecurse $PROJECT_NAME.gen/sources_1/bd/$BD_TOP/hdl/bd_top_wrapper.v
update_compile_order -fileset sources_1
set_property top bd_top_wrapper [current_fileset]
update_compile_order -fileset sources_1

##############################################################################
# extensible platform
##############################################################################

if {$EXTENSIBLE_PLATFORM} {
    set_property platform.extensible true [current_project]
    set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM0_LPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "HP1" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "HP2" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "HP3" memory "" is_range "false"}} $zynq_ultra_ps
    # set_property PFM.AXI_PORT {M00_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M01_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"}  M02_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M03_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M04_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M05_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M06_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"} M07_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "true"}} [get_bd_cells /smartconnect_1]
    set_property PFM.CLOCK {} [get_bd_cells /zynq_ultra_ps]
    set_property PFM.CLOCK {clk_100M {id "1" is_default "true" proc_sys_reset "/ps_reset_100M" status "fixed" freq_hz "99999000"}} [get_bd_cells /clk_wiz_0]
    # set_property PFM.IRQ {In0 {is_range "true"} In1 {is_range "true"}} [get_bd_cells /xlconcat_0]
    set_property platform.vendor {vendor} [current_project]
    set_property platform.board_id {lib} [current_project]
    set_property platform.version {1.0} [current_project]
    set_property pfm_name {vendor:lib:$PROJECT_NAME:1.0} [get_files -all $BD_TOP.bd]
}

##############################################################################
# Generate output products
##############################################################################

generate_target all [get_files  $PROJECT_NAME.srcs/sources_1/bd/$BD_TOP/$BD_TOP.bd]
# catch { config_ip_cache -export [get_ips -all bd_top_zynq_ultra_ps_e_0_0] }
# catch { config_ip_cache -export [get_ips -all bd_top_proc_sys_reset_0_0] }
# catch { config_ip_cache -export [get_ips -all bd_top_c_counter_binary_0_0] }
# catch { config_ip_cache -export [get_ips -all bd_top_system_ila_0_1] }
export_ip_user_files -of_objects [get_files $PROJECT_NAME.srcs/sources_1/bd/$BD_TOP/$BD_TOP.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] $PROJECT_NAME.srcs/sources_1/bd/$BD_TOP/$BD_TOP.bd]

close_bd_design [current_bd_design]
