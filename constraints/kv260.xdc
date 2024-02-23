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

set_property PACKAGE_PIN A12 [get_ports {fan_en_b[0]}] ; # som240_1_c24
set_property IOSTANDARD LVCMOS33 [get_ports {fan_en_b[0]}]
set_property SLEW SLOW [get_ports {fan_en_b[0]}]
set_property DRIVE 4 [get_ports {fan_en_b[0]}]

#################################################################################
# RPI camera
#################################################################################

set_property PACKAGE_PIN F11 [get_ports {rpi_cam_en}]
set_property IOSTANDARD LVCMOS33 [get_ports {rpi_cam_en}]
set_property SLEW SLOW [get_ports {rpi_cam_en}]
set_property DRIVE 4 [get_ports {rpi_cam_en}]