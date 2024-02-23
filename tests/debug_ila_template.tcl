# Create ILA
create_debug_core u_ila_0 ila

# Configure ILA properties
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]

# Connect clock
connect_debug_port u_ila_0/clk [get_nets [list $(IP_TOP_BD_NAME)}/zynq_ultra_ps/inst/pl_clk0 ]]

# Create and configure each probe, linked to a signal (probe0 is added by default, the rest need to be added by using 'create_debug_port u_ila_0 probe' )

set_property port_width 1 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list $(IP_TOP_BD_NAME)/path/to/module/signal_name ]]

create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][0]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][1]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][2]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][3]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][4]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][5]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][6]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][7]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][8]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][9]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][10]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][11]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][12]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][13]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][14]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][15]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][16]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][17]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][18]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][19]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][20]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][21]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][22]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][23]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][24]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][25]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][26]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][27]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][28]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][29]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][30]} {$(IP_TOP_BD_NAME)/path/to/module/record_signal_name[record_field_name][31]} ]]

# Save new constraints as temp_debug.xdc
file mkdir $(PROJECT_PATH)/$(PROJECT_NAME).srcs/constrs_1/new
close [ open $(PROJECT_PATH)/$(PROJECT_NAME).srcs/constrs_1/new/temp_debug.xdc w ]
add_files -fileset constrs_1 $(PROJECT_PATH)/$(PROJECT_NAME).srcs/constrs_1/new/temp_debug.xdc
set_property target_constrs_file $(PROJECT_PATH)/$(PROJECT_NAME).srcs/constrs_1/new/temp_debug.xdc [current_fileset -constrset]
save_constraints -force
