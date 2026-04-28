set_property IOSTANDARD LVCMOS33 [get_ports osc_clk]
set_property IOSTANDARD LVCMOS33 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_txc]
set_property PACKAGE_PIN G22 [get_ports osc_clk]
set_property PACKAGE_PIN D26 [get_ports reset_btn]
create_clock -period 20.000 -name osc_clk [get_ports osc_clk]

set_property PACKAGE_PIN AE1 [get_ports {rgmii_rd[3]}]
set_property PACKAGE_PIN AE2 [get_ports {rgmii_rd[2]}]
set_property PACKAGE_PIN AC3 [get_ports {rgmii_rd[1]}]
set_property PACKAGE_PIN AF3 [get_ports {rgmii_rd[0]}]
set_property PACKAGE_PIN Y3 [get_ports {rgmii_td[3]}]
set_property PACKAGE_PIN AB4 [get_ports {rgmii_td[2]}]
set_property PACKAGE_PIN AB1 [get_ports {rgmii_td[1]}]
set_property PACKAGE_PIN AC1 [get_ports {rgmii_td[0]}]
set_property PACKAGE_PIN AF4 [get_ports rgmii_rx_ctl]
set_property PACKAGE_PIN AB2 [get_ports rgmii_rxc]
set_property PACKAGE_PIN Y1 [get_ports rgmii_tx_ctl]
set_property PACKAGE_PIN AC2 [get_ports rgmii_txc]


set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property PACKAGE_PIN Y2 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports phy_rst_n]

set_property IOSTANDARD LVCMOS33 [get_ports {my_led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_led[0]}]
set_property PACKAGE_PIN E25 [get_ports {my_led[7]}]
set_property PACKAGE_PIN D25 [get_ports {my_led[6]}]
set_property PACKAGE_PIN D24 [get_ports {my_led[5]}]
set_property PACKAGE_PIN C26 [get_ports {my_led[4]}]
set_property PACKAGE_PIN C24 [get_ports {my_led[3]}]
set_property PACKAGE_PIN D23 [get_ports {my_led[2]}]
set_property PACKAGE_PIN A24 [get_ports {my_led[1]}]
set_property PACKAGE_PIN A23 [get_ports {my_led[0]}]

set_property PACKAGE_PIN J26 [get_ports {my_btns[0]}]
set_property PACKAGE_PIN E26 [get_ports {my_btns[1]}]
set_property PACKAGE_PIN G26 [get_ports {my_btns[2]}]
set_property PACKAGE_PIN H26 [get_ports {my_btns[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_btns[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_btns[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_btns[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {my_btns[0]}]

set_property DRIVE 12 [get_ports {my_led[7]}]
set_property DRIVE 12 [get_ports {my_led[6]}]
set_property DRIVE 12 [get_ports {my_led[5]}]
set_property DRIVE 12 [get_ports {my_led[4]}]
set_property DRIVE 12 [get_ports {my_led[3]}]
set_property DRIVE 12 [get_ports {my_led[2]}]
set_property DRIVE 12 [get_ports {my_led[1]}]
set_property DRIVE 12 [get_ports {my_led[0]}]

# set_property CLOCK_DOMAIN clk_100mhz [get_debug_cores dbg_hub]


connect_debug_port u_ila_0/probe8 [get_nets [list dsp_core/disp_a_wr_en]]
connect_debug_port u_ila_0/probe9 [get_nets [list dsp_core/disp_b_wr_en]]
connect_debug_port u_ila_0/probe12 [get_nets [list dsp_core/klin_a_wr_en]]
connect_debug_port u_ila_0/probe13 [get_nets [list dsp_core/klin_b_wr_en]]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_gen/inst/clk_mn]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 10 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dsp_core/u_k_lin/base_read_data[0]} {dsp_core/u_k_lin/base_read_data[1]} {dsp_core/u_k_lin/base_read_data[2]} {dsp_core/u_k_lin/base_read_data[3]} {dsp_core/u_k_lin/base_read_data[4]} {dsp_core/u_k_lin/base_read_data[5]} {dsp_core/u_k_lin/base_read_data[6]} {dsp_core/u_k_lin/base_read_data[7]} {dsp_core/u_k_lin/base_read_data[8]} {dsp_core/u_k_lin/base_read_data[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 10 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dsp_core/u_k_lin/cal_read_addr[0]} {dsp_core/u_k_lin/cal_read_addr[1]} {dsp_core/u_k_lin/cal_read_addr[2]} {dsp_core/u_k_lin/cal_read_addr[3]} {dsp_core/u_k_lin/cal_read_addr[4]} {dsp_core/u_k_lin/cal_read_addr[5]} {dsp_core/u_k_lin/cal_read_addr[6]} {dsp_core/u_k_lin/cal_read_addr[7]} {dsp_core/u_k_lin/cal_read_addr[8]} {dsp_core/u_k_lin/cal_read_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 18 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dsp_core/u_k_lin/c0_read_data[0]} {dsp_core/u_k_lin/c0_read_data[1]} {dsp_core/u_k_lin/c0_read_data[2]} {dsp_core/u_k_lin/c0_read_data[3]} {dsp_core/u_k_lin/c0_read_data[4]} {dsp_core/u_k_lin/c0_read_data[5]} {dsp_core/u_k_lin/c0_read_data[6]} {dsp_core/u_k_lin/c0_read_data[7]} {dsp_core/u_k_lin/c0_read_data[8]} {dsp_core/u_k_lin/c0_read_data[9]} {dsp_core/u_k_lin/c0_read_data[10]} {dsp_core/u_k_lin/c0_read_data[11]} {dsp_core/u_k_lin/c0_read_data[12]} {dsp_core/u_k_lin/c0_read_data[13]} {dsp_core/u_k_lin/c0_read_data[14]} {dsp_core/u_k_lin/c0_read_data[15]} {dsp_core/u_k_lin/c0_read_data[16]} {dsp_core/u_k_lin/c0_read_data[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dsp_core/bgsub_out_str[0]} {dsp_core/bgsub_out_str[1]} {dsp_core/bgsub_out_str[2]} {dsp_core/bgsub_out_str[3]} {dsp_core/bgsub_out_str[4]} {dsp_core/bgsub_out_str[5]} {dsp_core/bgsub_out_str[6]} {dsp_core/bgsub_out_str[7]} {dsp_core/bgsub_out_str[8]} {dsp_core/bgsub_out_str[9]} {dsp_core/bgsub_out_str[10]} {dsp_core/bgsub_out_str[11]} {dsp_core/bgsub_out_str[12]} {dsp_core/bgsub_out_str[13]} {dsp_core/bgsub_out_str[14]} {dsp_core/bgsub_out_str[15]} {dsp_core/bgsub_out_str[16]} {dsp_core/bgsub_out_str[17]} {dsp_core/bgsub_out_str[18]} {dsp_core/bgsub_out_str[19]} {dsp_core/bgsub_out_str[20]} {dsp_core/bgsub_out_str[21]} {dsp_core/bgsub_out_str[22]} {dsp_core/bgsub_out_str[23]} {dsp_core/bgsub_out_str[24]} {dsp_core/bgsub_out_str[25]} {dsp_core/bgsub_out_str[26]} {dsp_core/bgsub_out_str[27]} {dsp_core/bgsub_out_str[28]} {dsp_core/bgsub_out_str[29]} {dsp_core/bgsub_out_str[30]} {dsp_core/bgsub_out_str[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dsp_core/disp_b_wr_data[0]} {dsp_core/disp_b_wr_data[1]} {dsp_core/disp_b_wr_data[2]} {dsp_core/disp_b_wr_data[3]} {dsp_core/disp_b_wr_data[4]} {dsp_core/disp_b_wr_data[5]} {dsp_core/disp_b_wr_data[6]} {dsp_core/disp_b_wr_data[7]} {dsp_core/disp_b_wr_data[8]} {dsp_core/disp_b_wr_data[9]} {dsp_core/disp_b_wr_data[10]} {dsp_core/disp_b_wr_data[11]} {dsp_core/disp_b_wr_data[12]} {dsp_core/disp_b_wr_data[13]} {dsp_core/disp_b_wr_data[14]} {dsp_core/disp_b_wr_data[15]} {dsp_core/disp_b_wr_data[16]} {dsp_core/disp_b_wr_data[17]} {dsp_core/disp_b_wr_data[18]} {dsp_core/disp_b_wr_data[19]} {dsp_core/disp_b_wr_data[20]} {dsp_core/disp_b_wr_data[21]} {dsp_core/disp_b_wr_data[22]} {dsp_core/disp_b_wr_data[23]} {dsp_core/disp_b_wr_data[24]} {dsp_core/disp_b_wr_data[25]} {dsp_core/disp_b_wr_data[26]} {dsp_core/disp_b_wr_data[27]} {dsp_core/disp_b_wr_data[28]} {dsp_core/disp_b_wr_data[29]} {dsp_core/disp_b_wr_data[30]} {dsp_core/disp_b_wr_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 10 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {dsp_core/disp_b_wr_addr[0]} {dsp_core/disp_b_wr_addr[1]} {dsp_core/disp_b_wr_addr[2]} {dsp_core/disp_b_wr_addr[3]} {dsp_core/disp_b_wr_addr[4]} {dsp_core/disp_b_wr_addr[5]} {dsp_core/disp_b_wr_addr[6]} {dsp_core/disp_b_wr_addr[7]} {dsp_core/disp_b_wr_addr[8]} {dsp_core/disp_b_wr_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 10 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {dsp_core/disp_a_wr_addr[0]} {dsp_core/disp_a_wr_addr[1]} {dsp_core/disp_a_wr_addr[2]} {dsp_core/disp_a_wr_addr[3]} {dsp_core/disp_a_wr_addr[4]} {dsp_core/disp_a_wr_addr[5]} {dsp_core/disp_a_wr_addr[6]} {dsp_core/disp_a_wr_addr[7]} {dsp_core/disp_a_wr_addr[8]} {dsp_core/disp_a_wr_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 10 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {dsp_core/bg_wr_addr[0]} {dsp_core/bg_wr_addr[1]} {dsp_core/bg_wr_addr[2]} {dsp_core/bg_wr_addr[3]} {dsp_core/bg_wr_addr[4]} {dsp_core/bg_wr_addr[5]} {dsp_core/bg_wr_addr[6]} {dsp_core/bg_wr_addr[7]} {dsp_core/bg_wr_addr[8]} {dsp_core/bg_wr_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {dsp_core/disp_a_wr_we[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {dsp_core/disp_b_wr_we[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 32 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {dsp_core/disp_out_im[0]} {dsp_core/disp_out_im[1]} {dsp_core/disp_out_im[2]} {dsp_core/disp_out_im[3]} {dsp_core/disp_out_im[4]} {dsp_core/disp_out_im[5]} {dsp_core/disp_out_im[6]} {dsp_core/disp_out_im[7]} {dsp_core/disp_out_im[8]} {dsp_core/disp_out_im[9]} {dsp_core/disp_out_im[10]} {dsp_core/disp_out_im[11]} {dsp_core/disp_out_im[12]} {dsp_core/disp_out_im[13]} {dsp_core/disp_out_im[14]} {dsp_core/disp_out_im[15]} {dsp_core/disp_out_im[16]} {dsp_core/disp_out_im[17]} {dsp_core/disp_out_im[18]} {dsp_core/disp_out_im[19]} {dsp_core/disp_out_im[20]} {dsp_core/disp_out_im[21]} {dsp_core/disp_out_im[22]} {dsp_core/disp_out_im[23]} {dsp_core/disp_out_im[24]} {dsp_core/disp_out_im[25]} {dsp_core/disp_out_im[26]} {dsp_core/disp_out_im[27]} {dsp_core/disp_out_im[28]} {dsp_core/disp_out_im[29]} {dsp_core/disp_out_im[30]} {dsp_core/disp_out_im[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {dsp_core/disp_out_re[0]} {dsp_core/disp_out_re[1]} {dsp_core/disp_out_re[2]} {dsp_core/disp_out_re[3]} {dsp_core/disp_out_re[4]} {dsp_core/disp_out_re[5]} {dsp_core/disp_out_re[6]} {dsp_core/disp_out_re[7]} {dsp_core/disp_out_re[8]} {dsp_core/disp_out_re[9]} {dsp_core/disp_out_re[10]} {dsp_core/disp_out_re[11]} {dsp_core/disp_out_re[12]} {dsp_core/disp_out_re[13]} {dsp_core/disp_out_re[14]} {dsp_core/disp_out_re[15]} {dsp_core/disp_out_re[16]} {dsp_core/disp_out_re[17]} {dsp_core/disp_out_re[18]} {dsp_core/disp_out_re[19]} {dsp_core/disp_out_re[20]} {dsp_core/disp_out_re[21]} {dsp_core/disp_out_re[22]} {dsp_core/disp_out_re[23]} {dsp_core/disp_out_re[24]} {dsp_core/disp_out_re[25]} {dsp_core/disp_out_re[26]} {dsp_core/disp_out_re[27]} {dsp_core/disp_out_re[28]} {dsp_core/disp_out_re[29]} {dsp_core/disp_out_re[30]} {dsp_core/disp_out_re[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {dsp_core/klin_b_wr_we[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 10 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {dsp_core/klin_a_wr_addr[0]} {dsp_core/klin_a_wr_addr[1]} {dsp_core/klin_a_wr_addr[2]} {dsp_core/klin_a_wr_addr[3]} {dsp_core/klin_a_wr_addr[4]} {dsp_core/klin_a_wr_addr[5]} {dsp_core/klin_a_wr_addr[6]} {dsp_core/klin_a_wr_addr[7]} {dsp_core/klin_a_wr_addr[8]} {dsp_core/klin_a_wr_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 32 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {dsp_core/fft_out_real[0]} {dsp_core/fft_out_real[1]} {dsp_core/fft_out_real[2]} {dsp_core/fft_out_real[3]} {dsp_core/fft_out_real[4]} {dsp_core/fft_out_real[5]} {dsp_core/fft_out_real[6]} {dsp_core/fft_out_real[7]} {dsp_core/fft_out_real[8]} {dsp_core/fft_out_real[9]} {dsp_core/fft_out_real[10]} {dsp_core/fft_out_real[11]} {dsp_core/fft_out_real[12]} {dsp_core/fft_out_real[13]} {dsp_core/fft_out_real[14]} {dsp_core/fft_out_real[15]} {dsp_core/fft_out_real[16]} {dsp_core/fft_out_real[17]} {dsp_core/fft_out_real[18]} {dsp_core/fft_out_real[19]} {dsp_core/fft_out_real[20]} {dsp_core/fft_out_real[21]} {dsp_core/fft_out_real[22]} {dsp_core/fft_out_real[23]} {dsp_core/fft_out_real[24]} {dsp_core/fft_out_real[25]} {dsp_core/fft_out_real[26]} {dsp_core/fft_out_real[27]} {dsp_core/fft_out_real[28]} {dsp_core/fft_out_real[29]} {dsp_core/fft_out_real[30]} {dsp_core/fft_out_real[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 32 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {dsp_core/in_data[0]} {dsp_core/in_data[1]} {dsp_core/in_data[2]} {dsp_core/in_data[3]} {dsp_core/in_data[4]} {dsp_core/in_data[5]} {dsp_core/in_data[6]} {dsp_core/in_data[7]} {dsp_core/in_data[8]} {dsp_core/in_data[9]} {dsp_core/in_data[10]} {dsp_core/in_data[11]} {dsp_core/in_data[12]} {dsp_core/in_data[13]} {dsp_core/in_data[14]} {dsp_core/in_data[15]} {dsp_core/in_data[16]} {dsp_core/in_data[17]} {dsp_core/in_data[18]} {dsp_core/in_data[19]} {dsp_core/in_data[20]} {dsp_core/in_data[21]} {dsp_core/in_data[22]} {dsp_core/in_data[23]} {dsp_core/in_data[24]} {dsp_core/in_data[25]} {dsp_core/in_data[26]} {dsp_core/in_data[27]} {dsp_core/in_data[28]} {dsp_core/in_data[29]} {dsp_core/in_data[30]} {dsp_core/in_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 32 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {dsp_core/klin_out_str[0]} {dsp_core/klin_out_str[1]} {dsp_core/klin_out_str[2]} {dsp_core/klin_out_str[3]} {dsp_core/klin_out_str[4]} {dsp_core/klin_out_str[5]} {dsp_core/klin_out_str[6]} {dsp_core/klin_out_str[7]} {dsp_core/klin_out_str[8]} {dsp_core/klin_out_str[9]} {dsp_core/klin_out_str[10]} {dsp_core/klin_out_str[11]} {dsp_core/klin_out_str[12]} {dsp_core/klin_out_str[13]} {dsp_core/klin_out_str[14]} {dsp_core/klin_out_str[15]} {dsp_core/klin_out_str[16]} {dsp_core/klin_out_str[17]} {dsp_core/klin_out_str[18]} {dsp_core/klin_out_str[19]} {dsp_core/klin_out_str[20]} {dsp_core/klin_out_str[21]} {dsp_core/klin_out_str[22]} {dsp_core/klin_out_str[23]} {dsp_core/klin_out_str[24]} {dsp_core/klin_out_str[25]} {dsp_core/klin_out_str[26]} {dsp_core/klin_out_str[27]} {dsp_core/klin_out_str[28]} {dsp_core/klin_out_str[29]} {dsp_core/klin_out_str[30]} {dsp_core/klin_out_str[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 32 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {dsp_core/topsel_out_real[0]} {dsp_core/topsel_out_real[1]} {dsp_core/topsel_out_real[2]} {dsp_core/topsel_out_real[3]} {dsp_core/topsel_out_real[4]} {dsp_core/topsel_out_real[5]} {dsp_core/topsel_out_real[6]} {dsp_core/topsel_out_real[7]} {dsp_core/topsel_out_real[8]} {dsp_core/topsel_out_real[9]} {dsp_core/topsel_out_real[10]} {dsp_core/topsel_out_real[11]} {dsp_core/topsel_out_real[12]} {dsp_core/topsel_out_real[13]} {dsp_core/topsel_out_real[14]} {dsp_core/topsel_out_real[15]} {dsp_core/topsel_out_real[16]} {dsp_core/topsel_out_real[17]} {dsp_core/topsel_out_real[18]} {dsp_core/topsel_out_real[19]} {dsp_core/topsel_out_real[20]} {dsp_core/topsel_out_real[21]} {dsp_core/topsel_out_real[22]} {dsp_core/topsel_out_real[23]} {dsp_core/topsel_out_real[24]} {dsp_core/topsel_out_real[25]} {dsp_core/topsel_out_real[26]} {dsp_core/topsel_out_real[27]} {dsp_core/topsel_out_real[28]} {dsp_core/topsel_out_real[29]} {dsp_core/topsel_out_real[30]} {dsp_core/topsel_out_real[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 32 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {dsp_core/klin_a_wr_data[0]} {dsp_core/klin_a_wr_data[1]} {dsp_core/klin_a_wr_data[2]} {dsp_core/klin_a_wr_data[3]} {dsp_core/klin_a_wr_data[4]} {dsp_core/klin_a_wr_data[5]} {dsp_core/klin_a_wr_data[6]} {dsp_core/klin_a_wr_data[7]} {dsp_core/klin_a_wr_data[8]} {dsp_core/klin_a_wr_data[9]} {dsp_core/klin_a_wr_data[10]} {dsp_core/klin_a_wr_data[11]} {dsp_core/klin_a_wr_data[12]} {dsp_core/klin_a_wr_data[13]} {dsp_core/klin_a_wr_data[14]} {dsp_core/klin_a_wr_data[15]} {dsp_core/klin_a_wr_data[16]} {dsp_core/klin_a_wr_data[17]} {dsp_core/klin_a_wr_data[18]} {dsp_core/klin_a_wr_data[19]} {dsp_core/klin_a_wr_data[20]} {dsp_core/klin_a_wr_data[21]} {dsp_core/klin_a_wr_data[22]} {dsp_core/klin_a_wr_data[23]} {dsp_core/klin_a_wr_data[24]} {dsp_core/klin_a_wr_data[25]} {dsp_core/klin_a_wr_data[26]} {dsp_core/klin_a_wr_data[27]} {dsp_core/klin_a_wr_data[28]} {dsp_core/klin_a_wr_data[29]} {dsp_core/klin_a_wr_data[30]} {dsp_core/klin_a_wr_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 10 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {dsp_core/klin_b_wr_addr[0]} {dsp_core/klin_b_wr_addr[1]} {dsp_core/klin_b_wr_addr[2]} {dsp_core/klin_b_wr_addr[3]} {dsp_core/klin_b_wr_addr[4]} {dsp_core/klin_b_wr_addr[5]} {dsp_core/klin_b_wr_addr[6]} {dsp_core/klin_b_wr_addr[7]} {dsp_core/klin_b_wr_addr[8]} {dsp_core/klin_b_wr_addr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 32 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {dsp_core/fft_out_imag[0]} {dsp_core/fft_out_imag[1]} {dsp_core/fft_out_imag[2]} {dsp_core/fft_out_imag[3]} {dsp_core/fft_out_imag[4]} {dsp_core/fft_out_imag[5]} {dsp_core/fft_out_imag[6]} {dsp_core/fft_out_imag[7]} {dsp_core/fft_out_imag[8]} {dsp_core/fft_out_imag[9]} {dsp_core/fft_out_imag[10]} {dsp_core/fft_out_imag[11]} {dsp_core/fft_out_imag[12]} {dsp_core/fft_out_imag[13]} {dsp_core/fft_out_imag[14]} {dsp_core/fft_out_imag[15]} {dsp_core/fft_out_imag[16]} {dsp_core/fft_out_imag[17]} {dsp_core/fft_out_imag[18]} {dsp_core/fft_out_imag[19]} {dsp_core/fft_out_imag[20]} {dsp_core/fft_out_imag[21]} {dsp_core/fft_out_imag[22]} {dsp_core/fft_out_imag[23]} {dsp_core/fft_out_imag[24]} {dsp_core/fft_out_imag[25]} {dsp_core/fft_out_imag[26]} {dsp_core/fft_out_imag[27]} {dsp_core/fft_out_imag[28]} {dsp_core/fft_out_imag[29]} {dsp_core/fft_out_imag[30]} {dsp_core/fft_out_imag[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {dsp_core/klin_a_wr_we[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 8 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {dsp_core/log_pix_out[0]} {dsp_core/log_pix_out[1]} {dsp_core/log_pix_out[2]} {dsp_core/log_pix_out[3]} {dsp_core/log_pix_out[4]} {dsp_core/log_pix_out[5]} {dsp_core/log_pix_out[6]} {dsp_core/log_pix_out[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 32 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {dsp_core/klin_b_wr_data[0]} {dsp_core/klin_b_wr_data[1]} {dsp_core/klin_b_wr_data[2]} {dsp_core/klin_b_wr_data[3]} {dsp_core/klin_b_wr_data[4]} {dsp_core/klin_b_wr_data[5]} {dsp_core/klin_b_wr_data[6]} {dsp_core/klin_b_wr_data[7]} {dsp_core/klin_b_wr_data[8]} {dsp_core/klin_b_wr_data[9]} {dsp_core/klin_b_wr_data[10]} {dsp_core/klin_b_wr_data[11]} {dsp_core/klin_b_wr_data[12]} {dsp_core/klin_b_wr_data[13]} {dsp_core/klin_b_wr_data[14]} {dsp_core/klin_b_wr_data[15]} {dsp_core/klin_b_wr_data[16]} {dsp_core/klin_b_wr_data[17]} {dsp_core/klin_b_wr_data[18]} {dsp_core/klin_b_wr_data[19]} {dsp_core/klin_b_wr_data[20]} {dsp_core/klin_b_wr_data[21]} {dsp_core/klin_b_wr_data[22]} {dsp_core/klin_b_wr_data[23]} {dsp_core/klin_b_wr_data[24]} {dsp_core/klin_b_wr_data[25]} {dsp_core/klin_b_wr_data[26]} {dsp_core/klin_b_wr_data[27]} {dsp_core/klin_b_wr_data[28]} {dsp_core/klin_b_wr_data[29]} {dsp_core/klin_b_wr_data[30]} {dsp_core/klin_b_wr_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list dsp_core/bg_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list dsp_core/bgsub_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list dsp_core/bgsub_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list dsp_core/u_k_lin/cal_read_enable]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list dsp_core/disp_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list dsp_core/disp_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list dsp_core/fft_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list dsp_core/fft_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list dsp_core/in_row_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list dsp_core/klin_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list dsp_core/klin_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list dsp_core/klin_overflow]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list dsp_core/log_pix_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list dsp_core/log_pix_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list dsp_core/mag_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
set_property port_width 1 [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list dsp_core/mag_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
set_property port_width 1 [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list dsp_core/out_row_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
set_property port_width 1 [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list dsp_core/topsel_out_start]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
set_property port_width 1 [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list dsp_core/topsel_out_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_100mhz]
