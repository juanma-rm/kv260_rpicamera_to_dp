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
set zynq_ultra_ps [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps ]
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
    CONFIG.PSU__USE__IRQ1 {1}                                    \
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
# Interrupts (direct to PS GIC via pl_ps_irq0 — no axi_intc cascade)
# Avoids irq-xilinx kernel crash on 5.15 when loaded via DT overlay
##############################################################################

set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
set_property -dict [ list \
    CONFIG.NUM_PORTS {5} \
] $xlconcat_0

##############################################################################
# AXI Interconnects
##############################################################################

set axi_interc_hpm0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_interc_hpm0 ]
set_property -dict [ list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {8} \
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

# Raspberry PI enable pin (driven by AXI GPIO)
set rpi_cam_en [ create_bd_port -dir O -from 0 -to 0 rpi_cam_en ]

# AXI GPIO for IP software reset (demosaic bit0, gamma bit1, rpi_cam_en bit2, scaler bit3, frmbuf bit4, csc bit5)
# The driver (xlnx_rebase_v5.15) requires reset-gpios in DT
set axi_gpio_rst [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_rst ]
set_property -dict [ list \
    CONFIG.C_GPIO_WIDTH {6} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x3F} \
] $axi_gpio_rst

# Slice bit0 → demosaic reset
set gpio_slice_demosaic [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_demosaic ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {0} \
    CONFIG.DIN_TO {0} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_demosaic

# Slice bit1 → gamma reset
set gpio_slice_gamma [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_gamma ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {1} \
    CONFIG.DIN_TO {1} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_gamma

# Slice bit2 → RPi camera enable/reset
set gpio_slice_rpicam [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_rpicam ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {2} \
    CONFIG.DIN_TO {2} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_rpicam

# Slice bit3 → scaler reset
set gpio_slice_scaler [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_scaler ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {3} \
    CONFIG.DIN_TO {3} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_scaler

# Slice bit4 → frmbuf reset
set gpio_slice_frmbuf [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_frmbuf ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {4} \
    CONFIG.DIN_TO {4} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_frmbuf

# Slice bit5 → CSC reset
set gpio_slice_csc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 gpio_slice_csc ]
set_property -dict [ list \
    CONFIG.DIN_WIDTH {6} \
    CONFIG.DIN_FROM {5} \
    CONFIG.DIN_TO {5} \
    CONFIG.DOUT_WIDTH {1} \
] $gpio_slice_csc

# MIPI CSI2 RX
set mipi_csi2_rx_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:6.0 mipi_csi2_rx_0 ]
set_property -dict [ list \
    CONFIG.AXIS_TDEST_WIDTH {4} \
    CONFIG.CLK_LANE_IO_LOC {D7} \
    CONFIG.CLK_LANE_IO_LOC_NAME {IO_L13P_T2L_N0_GC_QBC_66} \
    CONFIG.CMN_NUM_LANES {2} \
    CONFIG.CMN_NUM_PIXELS {1} \
    CONFIG.CMN_PXL_FORMAT {RAW10} \
    CONFIG.CSI_BUF_DEPTH {4096} \
    CONFIG.C_CLK_LANE_IO_POSITION {26} \
    CONFIG.C_CSI_EN_CRC {false} \
    CONFIG.C_CSI_FILTER_USERDATATYPE {false} \
    CONFIG.C_DATA_LANE0_IO_POSITION {28} \
    CONFIG.C_DATA_LANE1_IO_POSITION {30} \
    CONFIG.C_DPHY_LANES {2} \
    CONFIG.C_EN_BG0_PIN0 {false} \
    CONFIG.C_EN_BG1_PIN0 {false} \
    CONFIG.C_HS_LINE_RATE {912} \
    CONFIG.C_HS_SETTLE_NS {145} \
    CONFIG.C_STRETCH_LINE_RATE {1500} \
    CONFIG.DATA_LANE0_IO_LOC {E5} \
    CONFIG.DATA_LANE0_IO_LOC_NAME {IO_L14P_T2L_N2_GC_66} \
    CONFIG.DATA_LANE1_IO_LOC {G6} \
    CONFIG.DATA_LANE1_IO_LOC_NAME {IO_L15P_T2L_N4_AD11P_66} \
    CONFIG.DPHYRX_BOARD_INTERFACE {som240_1_connector_mipi_csi_raspi} \
    CONFIG.DPY_EN_REG_IF {false} \
    CONFIG.DPY_LINE_RATE {912} \
    CONFIG.HP_IO_BANK_SELECTION {66} \
    CONFIG.SupportLevel {1} \
    CONFIG.VFB_TU_WIDTH {1} \
] $mipi_csi2_rx_0

# AXIS Subset Converter: 10-bit to 8-bit conversion (RAW10 to RAW8 Bayer)
set axis_subset_converter_10_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 axis_subset_converter_10_8 ]
set_property -dict [list \
  CONFIG.S_TDATA_NUM_BYTES {2} \
  CONFIG.S_TDEST_WIDTH {10} \
  CONFIG.M_TDATA_NUM_BYTES {1} \
  CONFIG.M_TDEST_WIDTH {1} \
  CONFIG.TDATA_REMAP {tdata[9:2]} \
] $axis_subset_converter_10_8

# Video Demosaic
set v_demosaic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_demosaic:1.1 v_demosaic_0 ]
set_property -dict [ list \
    CONFIG.MAX_COLS {4096} \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.MAX_ROWS {2560} \
    CONFIG.SAMPLES_PER_CLOCK {1} \
] $v_demosaic_0

# Video Gamma LUT
set v_gamma_lut_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_gamma_lut:1.1 v_gamma_lut_0 ]
set_property -dict [ list \
    CONFIG.MAX_COLS {4096} \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.MAX_ROWS {2560} \
] $v_gamma_lut_0

# VPSS CSC (Color Space Conversion)
set v_proc_ss_csc [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_proc_ss:2.3 v_proc_ss_csc ]
set_property -dict [ list \
    CONFIG.C_MAX_COLS {4096} \
    CONFIG.C_MAX_DATA_WIDTH {8} \
    CONFIG.C_MAX_ROWS {2160} \
    CONFIG.C_SAMPLES_PER_CLK {1} \
    CONFIG.C_TOPOLOGY {3} \
] $v_proc_ss_csc

# VPSS Scaler
set v_proc_ss_scaler [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_proc_ss:2.3 v_proc_ss_scaler ]
set_property -dict [ list \
    CONFIG.C_MAX_COLS {4096} \
    CONFIG.C_MAX_DATA_WIDTH {8} \
    CONFIG.C_MAX_ROWS {2160} \
    CONFIG.C_SAMPLES_PER_CLK {1} \
    CONFIG.C_TOPOLOGY {0} \
] $v_proc_ss_scaler

# Video Frame Buffer Write
set v_frmbuf_wr_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_frmbuf_wr:3.0 v_frmbuf_wr_0 ]
set_property -dict [ list \
    CONFIG.HAS_BGR8 {1} \
    CONFIG.HAS_BGRX8 {1} \
    CONFIG.HAS_RGBX8 {1} \
    CONFIG.HAS_RGB8 {1} \
    CONFIG.HAS_XRGB8 {1} \
    CONFIG.HAS_XBGR8 {1} \
    CONFIG.HAS_Y_UV8_420 {1} \
    CONFIG.MAX_COLS {4096} \
    CONFIG.MAX_NR_PLANES {3} \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.MAX_ROWS {2160} \
    CONFIG.SAMPLES_PER_CLOCK {1} \
] $v_frmbuf_wr_0

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

# Interrupts — direct to PS GIC Port 1 (SPI 104-111)
connect_bd_net [get_bd_pins v_frmbuf_wr_0/interrupt] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins mipi_csi2_rx_0/csirxss_csi_irq] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins v_demosaic_0/interrupt] [get_bd_pins xlconcat_0/In3]
connect_bd_net [get_bd_pins v_gamma_lut_0/interrupt] [get_bd_pins xlconcat_0/In4]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps/pl_ps_irq1]

# RPI I2C
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aresetn] $rstn_300M
connect_bd_intf_net -intf_net axi_iic_0_IIC [get_bd_intf_pins axi_iic_0/IIC] [get_bd_intf_ports som240_1_connector_hda_iic_switch]
connect_bd_intf_net [get_bd_intf_pins axi_iic_0/S_AXI] [get_bd_intf_pins axi_interc_hpm0/M02_AXI]

# RPI enable connected to AXI GPIO bit 2
connect_bd_net [get_bd_ports rpi_cam_en] [get_bd_pins gpio_slice_rpicam/Dout]

# MIPI CSI RX
connect_bd_net [get_bd_pins mipi_csi2_rx_0/lite_aclk] $clk_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/lite_aresetn] $rstn_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/dphy_clk_200M] $clk_200M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/video_aclk] $clk_300M
connect_bd_net [get_bd_pins mipi_csi2_rx_0/video_aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_0/video_out] [get_bd_intf_pins axis_subset_converter_10_8/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_0/mipi_phy_if] [get_bd_intf_ports som240_1_connector_mipi_csi_raspi]
connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_0/csirxss_s_axi] [get_bd_intf_pins axi_interc_hpm0/M00_AXI]

# AXIS Subset Converter: RAW10 to RAW8 Bayer conversion
connect_bd_net [get_bd_pins axis_subset_converter_10_8/aclk] $clk_300M
connect_bd_net [get_bd_pins axis_subset_converter_10_8/aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins axis_subset_converter_10_8/M_AXIS] [get_bd_intf_pins v_demosaic_0/s_axis_video]

# AXI GPIO reset controller
connect_bd_net [get_bd_pins axi_gpio_rst/s_axi_aclk] $clk_300M
connect_bd_net [get_bd_pins axi_gpio_rst/s_axi_aresetn] $rstn_300M
connect_bd_intf_net [get_bd_intf_pins axi_gpio_rst/S_AXI] [get_bd_intf_pins axi_interc_hpm0/M05_AXI]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_demosaic/Din]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_gamma/Din]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_rpicam/Din]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_scaler/Din]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_frmbuf/Din]
connect_bd_net [get_bd_pins axi_gpio_rst/gpio_io_o] [get_bd_pins gpio_slice_csc/Din]

# Video Demosaic
connect_bd_net [get_bd_pins v_demosaic_0/ap_clk] $clk_300M
connect_bd_net [get_bd_pins v_demosaic_0/ap_rst_n] [get_bd_pins gpio_slice_demosaic/Dout]
connect_bd_intf_net [get_bd_intf_pins v_demosaic_0/s_axi_CTRL] [get_bd_intf_pins axi_interc_hpm0/M01_AXI]
connect_bd_intf_net [get_bd_intf_pins v_demosaic_0/m_axis_video] [get_bd_intf_pins v_gamma_lut_0/s_axis_video]

# Video Gamma LUT
connect_bd_net [get_bd_pins v_gamma_lut_0/ap_clk] $clk_300M
connect_bd_net [get_bd_pins v_gamma_lut_0/ap_rst_n] [get_bd_pins gpio_slice_gamma/Dout]
connect_bd_intf_net [get_bd_intf_pins v_gamma_lut_0/s_axi_CTRL] [get_bd_intf_pins axi_interc_hpm0/M03_AXI]
connect_bd_intf_net [get_bd_intf_pins v_gamma_lut_0/m_axis_video] [get_bd_intf_pins v_proc_ss_csc/s_axis]

# VPSS CSC (Color Space Conversion)
connect_bd_net [get_bd_pins v_proc_ss_csc/aclk] $clk_300M
connect_bd_net [get_bd_pins v_proc_ss_csc/aresetn] [get_bd_pins gpio_slice_csc/Dout]
connect_bd_intf_net [get_bd_intf_pins v_proc_ss_csc/s_axi_ctrl] [get_bd_intf_pins axi_interc_hpm0/M07_AXI]
connect_bd_intf_net [get_bd_intf_pins v_proc_ss_csc/m_axis] [get_bd_intf_pins v_proc_ss_scaler/s_axis]

# VPSS Scaler
connect_bd_net [get_bd_pins v_proc_ss_scaler/aclk_axis] $clk_300M
connect_bd_net [get_bd_pins v_proc_ss_scaler/aclk_ctrl] $clk_300M
connect_bd_net [get_bd_pins v_proc_ss_scaler/aresetn_ctrl] [get_bd_pins gpio_slice_scaler/Dout]
connect_bd_intf_net [get_bd_intf_pins v_proc_ss_scaler/s_axi_ctrl] [get_bd_intf_pins axi_interc_hpm0/M04_AXI]
connect_bd_intf_net [get_bd_intf_pins v_proc_ss_scaler/m_axis] [get_bd_intf_pins v_frmbuf_wr_0/s_axis_video]

# Video Frame Buffer Write
connect_bd_net [get_bd_pins v_frmbuf_wr_0/ap_clk] $clk_300M
connect_bd_net [get_bd_pins v_frmbuf_wr_0/ap_rst_n] [get_bd_pins gpio_slice_frmbuf/Dout]
connect_bd_intf_net [get_bd_intf_pins v_frmbuf_wr_0/s_axi_CTRL] [get_bd_intf_pins axi_interc_hpm0/M06_AXI]
connect_bd_intf_net [get_bd_intf_pins v_frmbuf_wr_0/m_axi_mm_video] [get_bd_intf_pins axi_interc_hp0/S01_AXI]

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

# Framebuffer memory map
assign_bd_address -target_address_space /v_frmbuf_wr_0/Data_m_axi_mm_video [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_DDR_LOW] -force
assign_bd_address -target_address_space /v_frmbuf_wr_0/Data_m_axi_mm_video [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_QSPI] -force
assign_bd_address -target_address_space /v_frmbuf_wr_0/Data_m_axi_mm_video [get_bd_addr_segs zynq_ultra_ps/SAXIGP2/HP0_LPS_OCM] -force
exclude_bd_addr_seg [get_bd_addr_segs v_frmbuf_wr_0/Data_m_axi_mm_video/SEG_zynq_ultra_ps_HP0_DDR_HIGH]

# PS memory map: how it sees the PL AXI devices
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs mipi_csi2_rx_0/csirxss_s_axi/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs v_demosaic_0/s_axi_CTRL/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs v_gamma_lut_0/s_axi_CTRL/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs v_proc_ss_csc/s_axi_ctrl/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs v_frmbuf_wr_0/s_axi_CTRL/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs v_proc_ss_scaler/s_axi_ctrl/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs axi_iic_0/S_AXI/Reg] -force
assign_bd_address -target_address_space /zynq_ultra_ps/Data [get_bd_addr_segs axi_gpio_rst/S_AXI/Reg] -force

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
    set_property PFM.AXI_PORT { \
        M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} \
        M_AXI_HPM0_LPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} \
        S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} \
        S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} \
        S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} \
        S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "HP1" memory "" is_range "false"} \
        S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "HP2" memory "" is_range "false"} \
        S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "HP3" memory "" is_range "false"} \
    } $zynq_ultra_ps
    set_property PFM.CLOCK {} [get_bd_cells /zynq_ultra_ps]
    set_property PFM.CLOCK {clk_100M {id "1" is_default "true" proc_sys_reset "/ps_reset_100M" status "fixed" freq_hz "99999000"}} [get_bd_cells /clk_wiz_0]
    # set_property PFM.IRQ {In0 {is_range "true"} In1 {is_range "true"}} [get_bd_cells /xlconcat_0]
    set_property platform.vendor {vendor} [current_project]
    set_property platform.board_id {lib} [current_project]
    set_property platform.version {1.0} [current_project]
    set_property pfm_name "vendor:lib:${PROJECT_NAME}:1.0" [get_files -all $BD_TOP.bd]
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
