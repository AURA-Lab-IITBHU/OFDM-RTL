# Timing constraints for ofdm_axi_lite.
#
# Intended integration on a Zynq: connect s_axi_aclk to the processing system
# FCLK_CLK0 running at 50 MHz (PL0_REF_CTRL = 50.000) and s_axi_aresetn to
# FCLK_RESET0_N. Both are in the same clock domain as the AXI interconnect, so
# no I/O timing constraints are required for the PS-connected ports.
#
# Without this clock, synthesis reports "No constraint files found" and no
# timing analysis is performed at all.

create_clock -period 20.000 -waveform {0.000 10.000} -name s_axi_clk [get_ports s_axi_aclk]