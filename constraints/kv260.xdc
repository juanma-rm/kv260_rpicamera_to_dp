#################################################################################
# XDC constraints for the AMD KV260 board
# part: XCK26-SFVC784-2LV-C/I
#################################################################################

#################################################################################
# General configuration
#################################################################################


#################################################################################
# PMODs
#################################################################################

set_property PACKAGE_PIN H12 [ get_ports {pmod[0]} ] ; # PMOD pin 1 - som240_1_a17
set_property PACKAGE_PIN B10 [ get_ports {pmod[1]} ] ; # PMOD pin 2 - som240_1_b20
set_property PACKAGE_PIN E10 [ get_ports {pmod[2]} ] ; # PMOD pin 3 - som240_1_d20
set_property PACKAGE_PIN E12 [ get_ports {pmod[3]} ] ; # PMOD pin 4 - som240_1_b21
set_property PACKAGE_PIN D10 [ get_ports {pmod[4]} ] ; # PMOD pin 5 - som240_1_d21
set_property PACKAGE_PIN D11 [ get_ports {pmod[5]} ] ; # PMOD pin 6 - som240_1_b22
set_property PACKAGE_PIN C11 [ get_ports {pmod[6]} ] ; # PMOD pin 7 - som240_1_d22
set_property PACKAGE_PIN B11 [ get_ports {pmod[7]} ] ; # PMOD pin 8 - som240_1_c22
set_property IOSTANDARD LVCMOS33 [get_ports pmod*]
set_property SLEW SLOW [get_ports pmod*]
set_property DRIVE 12 [get_ports pmod*]

#################################################################################
# Fan Speed Enable
#################################################################################

set_property PACKAGE_PIN    A12         [get_ports {fan_en_b[0]}] ; # som240_1_c24
set_property IOSTANDARD     LVCMOS33    [get_ports {fan_en_b[0]}]
set_property SLEW           SLOW        [get_ports {fan_en_b[0]}]
set_property DRIVE          4           [get_ports {fan_en_b[0]}]

#################################################################################
# RPI camera
#################################################################################

set_property PACKAGE_PIN    F11         [get_ports {rpi_cam_en}]; # Bank  45 VCCO - som240_1_b13 - IO_L6N_HDGC_45 (som240_1_a15)
set_property IOSTANDARD     LVCMOS33    [get_ports {rpi_cam_en}]
set_property SLEW           SLOW        [get_ports {rpi_cam_en}]
set_property DRIVE          4           [get_ports {rpi_cam_en}]

# MIPI signals contraints retrieved from board file, so commented here
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_data_p[1]"]; # Net name HPA12_P (som240_1_a9)
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_data_n[1]"]; # Net name HPA12_N (som240_1_a10)
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_data_p[0]"]; # Net name HPA11_P (som240_1_b10)
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_data_n[0]"]; # Net name HPA11_N (som240_1_b11)
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_clk_p"]    ; # Net name HPA10_CC_P (som240_1_c12)
# set_property IOSTANDARD     MIPI_DPHY_DCI   [get_ports "mipi_phy_if_0_clk_n"]    ; # Net name HPA10_CC_N (som240_1_c13)
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_clk_n"]    ; # Net name HPA10_CC_N
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_clk_p"]    ; # Net name HPA10_CC_P
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_data_n[0]"]; # Net name HPA11_N
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_data_p[0]"]; # Net name HPA11_P
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_data_n[1]"]; # Net name HPA12_N
# set_property DIFF_TERM_ADV  TERM_100        [get_ports "mipi_phy_if_0_data_p[1]"]; # Net name HPA12_P

#################################################################################
# I2C (for usage from PS)
#################################################################################

set_property PACKAGE_PIN    F10         [get_ports "IIC_1_0_sda_io"]; # Bank  45 VCCO - som240_1_b13 - IO_L5N_HDGC_45 (som240_1_d17)
set_property PACKAGE_PIN    G11         [get_ports "IIC_1_0_scl_io"]; # Bank  45 VCCO - som240_1_b13 - IO_L5P_HDGC_45 (som240_1_d16)
set_property IOSTANDARD     LVCMOS33    [get_ports "IIC_1_0_scl_io"]; # Net name HDA00_CC (som240_1_d16)
set_property IOSTANDARD     LVCMOS33    [get_ports "IIC_1_0_sda_io"]; # Net name HDA01 (som240_1_d17)
set_property SLEW           SLOW        [get_ports "IIC_1_0_scl_io"]; # Net name HDA00_CC
set_property SLEW           SLOW        [get_ports "IIC_1_0_sda_io"]; # Net name HDA01
set_property DRIVE          4           [get_ports "IIC_1_0_scl_io"]; # Net name HDA00_CC
set_property DRIVE          4           [get_ports "IIC_1_0_sda_io"]; # Net name HDA01