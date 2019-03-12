# This file was generated using the transceiver wizard and then copying the
# TCL console.
   create_ip -name gtwizard -vendor xilinx.com -library ip -version 3.6 -module_name TimingGtx
   set_property -dict [list \
      CONFIG.identical_val_tx_line_rate {3.7142857}\
      CONFIG.identical_val_tx_reference_clock {185.714}\
      CONFIG.gt0_val_tx_data_width {16}\
      CONFIG.gt0_val_encoding {8B/10B}\
      CONFIG.gt0_val_rx_data_width {16}\
      CONFIG.gt0_val_decoding {8B/10B}\
      CONFIG.gt0_val_drp_clock {156.25}\
      CONFIG.gt0_val_txbuf_en {false}\
      CONFIG.gt0_val_rxbuf_en {false}\
      CONFIG.gt0_val_comma_preset {User_defined}\
      CONFIG.gt0_val_align_comma_word {Two_Byte_Boundaries}\
      CONFIG.gt0_val_port_rxslide {false}\
      CONFIG.gt0_val_pd_trans_time_non_p2 {25}\
      CONFIG.gt0_val_port_loopback {true}\
      CONFIG.identical_val_rx_line_rate {3.7142857}\
      CONFIG.gt_val_tx_pll {CPLL}\
      CONFIG.gt_val_rx_pll {CPLL}\
      CONFIG.identical_val_rx_reference_clock {185.714}\
      CONFIG.gt0_val_tx_line_rate {3.7142857}\
      CONFIG.gt0_val_tx_int_datawidth {20}\
      CONFIG.gt0_val_tx_reference_clock {185.714}\
      CONFIG.gt0_val_rx_line_rate {3.7142857}\
      CONFIG.gt0_val_rx_data_width {16}\
      CONFIG.gt0_val_rx_int_datawidth {20}\
      CONFIG.gt0_val_rx_reference_clock {185.714}\
      CONFIG.gt0_val_cpll_fbdiv {2}\
      CONFIG.gt0_val_cpll_rxout_div {1}\
      CONFIG.gt0_val_cpll_txout_div {1}\
      CONFIG.gt0_val_port_rxcharisk {true}\
      CONFIG.gt0_val_port_txpolarity {true}\
      CONFIG.gt0_val_port_rxpolarity {true}\
      CONFIG.gt0_val_tx_buffer_bypass_mode {Auto}\
      CONFIG.gt0_val_txoutclk_source {true}\
      CONFIG.gt0_val_rx_buffer_bypass_mode {Auto}\
      CONFIG.gt0_val_rxusrclk {RXOUTCLK}\
      CONFIG.gt0_val_dfe_mode {LPM-Auto}\
      CONFIG.gt0_val_rx_termination_voltage {Programmable}\
      CONFIG.gt0_val_rx_cm_trim {800}\
      CONFIG.gt0_val_clk_cor_seq_1_1 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_1_2 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_1_3 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_1_4 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_2_1 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_2_2 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_2_3 {00000000}\
      CONFIG.gt0_val_clk_cor_seq_2_4 {00000000}\
      CONFIG.gt0_val_rxslide_mode {OFF}\
   ] [get_ips TimingGtx]
