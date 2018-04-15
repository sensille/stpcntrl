set_property -dict {PACKAGE_PIN N11 IOSTANDARD LVCMOS33} [get_ports clk_50mhz]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports led_0]
set_property -dict {PACKAGE_PIN B6 IOSTANDARD LVCMOS33} [get_ports led_1]
set_property -dict {PACKAGE_PIN B7 IOSTANDARD LVCMOS33} [get_ports step]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports dir]
set_property -dict {PACKAGE_PIN G5 IOSTANDARD LVCMOS33} [get_ports home]
set_property -dict {PACKAGE_PIN C7 IOSTANDARD LVCMOS33} [get_ports rev]
set_property -dict {PACKAGE_PIN A7 IOSTANDARD LVCMOS33} [get_ports sck]
set_property -dict {PACKAGE_PIN B5 IOSTANDARD LVCMOS33} [get_ports sdi]
set_property -dict {PACKAGE_PIN K5 IOSTANDARD LVCMOS33} [get_ports sen]

set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports debug1]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33} [get_ports debug2]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD LVCMOS33} [get_ports debug3]
set_property -dict {PACKAGE_PIN N3 IOSTANDARD LVCMOS33} [get_ports debug4]

create_clock -period 20.000 [get_ports clk_50mhz]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sck_IBUF]


set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 3 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
