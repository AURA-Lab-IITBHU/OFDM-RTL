# -----------------------------------------------------------------------------
# build_bd.tcl - build the Zynq system around ofdm_axi_lite and produce a bitstream.
#
#   vivado -mode batch -source fpga/build_bd.tcl
#
# Creates (or overwrites) ofdm_bd/ in the repo root, as a real on-disk project
# (module references need a project with automatic compile order; an in-memory
# project is manual-order and cannot resolve them).
#
# Design:
#   processing_system7_0/M_AXI_GP0 -> (AXI interconnect, added by automation)
#                                  -> ofdm_axi_lite_0/s_axi
#   processing_system7_0/FCLK_CLK0 -> ofdm_axi_lite_0/s_axi_aclk
#   proc_sys_reset (automation)    -> ofdm_axi_lite_0/s_axi_aresetn
#
# The AXI interface name is lowercase "s_axi", taken from the XIL_INTERFACENAME
# attributes in fpga/ofdm_axi_lite.v (lines 35 and 54). Do not spell it "S_AXI".
#
# NOTE: fpga/ofdm_axi_lite.xdc is deliberately NOT added here: s_axi_aclk is
# driven by FCLK_CLK0 inside the block design, so it is not a top-level port and
# its create_clock would fail to match.
# -----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set out_dir    [file normalize [file join $repo_root ofdm_bd]]

set part_name  xc7z020clg484-1
set fclk_mhz   50
set bd_name    ofdm_system

# Desired base address of the AXI-Lite slave. Read the printed value at the end
# of the run; do not assume it was honoured.
set gp_base    0x43C00000

puts "=== ofdm build_bd ==="
puts "repo     : $repo_root"
puts "out      : $out_dir"
puts "part     : $part_name"
puts "FCLK_CLK0: $fclk_mhz MHz"

# ---------------------------------------------------------------- project ----
file delete -force $out_dir
create_project ofdm_bd $out_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# Automatic compile order is REQUIRED for create_bd_cell -type module.
set_property source_mgmt_mode All [current_project]

# If the ZedBoard board files are installed, use them so the PS7 gets the right
# DDR3 and MIO configuration. This is what lets the FSBL boot and gives the
# standalone app memory to run in. It is unrelated to the design's data path:
# there is no PL-side DDR traffic, the frame lives in flip-flops and software
# reads the 320 words back over AXI.
set use_preset 0
set zb [get_board_parts -quiet *zedboard*]
if {[llength $zb] > 0} {
  set_property board_part [lindex $zb 0] [current_project]
  set use_preset 1
  puts "INFO: using board part [lindex $zb 0]"
} else {
  puts "INFO: no ZedBoard board files found; PS7 DDR/MIO use defaults"
}

# ---------------------------------------------------------------- sources ----
# full.v is an `include aggregator for src/. Both the repo root and src/ are
# include dirs so `include "src/..." and the bare `include "FFT64.v" inside
# src/ifft_64.v both resolve.
add_files -norecurse [file join $repo_root full.v]
add_files -norecurse [file join $repo_root fpga ofdm_axi_lite.v]
set_property include_dirs [list $repo_root [file join $repo_root src]] [get_filesets sources_1]
update_compile_order -fileset sources_1

# ------------------------------------------------------------ block design ----
create_bd_design $bd_name

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Board preset (if available) plus external FIXED_IO only.
#
# DDR is deliberately NOT in the make_external list. On Zynq-7000 the PS DDR
# pins are dedicated PS MIO and are configured by apply_board_preset; the
# make_external DDR option is an HP-port concept from Zynq UltraScale+ and has
# no meaning here. The PS keeps its own DDR3 controller, which is all the app
# needs.
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
  -config [list make_external "FIXED_IO" apply_board_preset $use_preset \
                Master "Disable" Slave "Disable"] \
  [get_bd_cells processing_system7_0]

# Applied AFTER the preset so the preset cannot override them.
set_property -dict [list \
  CONFIG.PCW_USE_M_AXI_GP0             {1} \
  CONFIG.PCW_EN_CLK0_PORT              {1} \
  CONFIG.PCW_EN_RST0_PORT              {1} \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ  $fclk_mhz \
  CONFIG.PCW_USE_FABRIC_INTERRUPT      {0} \
  CONFIG.PCW_USE_S_AXI_ACP             {0} \
  CONFIG.PCW_USE_S_AXI_GP0             {0} \
  CONFIG.PCW_USE_S_AXI_GP1             {0} \
  ] [get_bd_cells processing_system7_0]

# Wrap the hand-written AXI wrapper as a module reference. update_compile_order
# first so the HDL is elaborated before the module is referenced by name.
update_compile_order -fileset sources_1
create_bd_cell -type module -reference ofdm_axi_lite ofdm_axi_lite_0

# Automation adds the interconnect and a proc_sys_reset, and wires clock and
# reset itself -- s_axi_aresetn is a declared RST interface (ofdm_axi_lite.v:31,
# plus ASSOCIATED_RESET on the clock at line 29), so a manual connect_bd_net
# here would fail with "already connected".
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/processing_system7_0/M_AXI_GP0" Slave "/ofdm_axi_lite_0/s_axi" Clk "Auto"} \
  [get_bd_intf_pins ofdm_axi_lite_0/s_axi]

# ---------------------------------------------------------------- addresses ---
assign_bd_address

set gp_space [get_bd_addr_spaces processing_system7_0/Data]
set seg [get_bd_addr_segs -of_objects $gp_space -filter {NAME =~ "*ofdm_axi_lite_0*"}]
if {[llength $seg] > 0} {
  set seg [lindex $seg 0]
  if {[catch {
    set_property range  4K        $seg
    set_property offset $gp_base  $seg
  } msg]} {
    puts "WARNING: could not pin address to $gp_base ($msg); using assigned value"
  }
  set actual [get_property offset $seg]
  puts ""
  puts "############################################################"
  puts "#  OFDM_BASE = $actual"
  puts "#  Set this in fpga/main.c (currently 0x43C00000U)."
  puts "############################################################"
  puts ""
} else {
  puts "WARNING: ofdm_axi_lite address segment not found; check Address Editor"
}
report_bd_address

validate_bd_design
save_bd_design

# ------------------------------------------------------------------ wrapper ---
set bd_file [get_files ${bd_name}.bd]
make_wrapper -files $bd_file -top -import
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1
generate_target all $bd_file

# ----------------------------------------------------------------- finalize ---
if {[catch {set_property strategy {Performance_ExplorePostRoutePhysOpt} [get_runs impl_1]} msg]} {
  puts "INFO: strategy not set on impl_1 ($msg)"
}

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "SYNTHESIS FAILED - see the run log."
}
puts "=== synthesis complete ==="

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "IMPLEMENTATION DID NOT REACH 100% - see the run log."
}

open_run impl_1
report_utilization    -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_drc            -file [file join $out_dir drc.rpt]

# Hardware handoff for Vitis (XSA with bitstream).
write_hw_platform -fixed -include_bit -force [file join $out_dir ${bd_name}.xsa]

puts ""
puts "=== timing summary ==="
puts "worst setup slack: [get_property SLACK [get_timing_paths -max_paths 1 -setup]]"
puts "reports + [file join $out_dir ${bd_name}.xsa] written to $out_dir"
puts "=== DONE ==="
