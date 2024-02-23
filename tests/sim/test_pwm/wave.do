onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /pwm/clk_i
add wave -noupdate /pwm/rst_i
add wave -noupdate -radix unsigned /pwm/count_in_freq
add wave -noupdate /pwm/clk_pwm
add wave -noupdate -radix unsigned /pwm/duty_cycle_in
add wave -noupdate -radix unsigned /pwm/duty_cycle_reg
add wave -noupdate -radix unsigned /pwm/count_pwm_freq
add wave -noupdate /pwm/pwm_period_start
add wave -noupdate /pwm/pwm_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {20276680 ps} 0} {{Cursor 2} {116996094 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {130294501 ps}
