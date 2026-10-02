# -----------------------------------------------------------------------------
# build_bd.tcl - build the Zynq system around ofdm_axi_lite and produce a bitstream.
#
#   vivado -mode batch -source fpga/build_bd.tcl
#
# Creates (or overwrites) ofdm_bd/ in the current directory.
#
# Design:
#   processing_system7_0/M_AXI_GP0 (32-bit)  ->  ofdm_axi_lite_0/S_AXI
#   processing_system7_0/FCLK_CLK0           ->  ofdm_axi_lite_0/s_axi_aclk
#   processing_system7_0/FCLK_RESET0_N       ->  ofdm_axi_lite_0/s_axi_aresetn
#
# A single 32-bit AXI4-Lite slave in a 4 KB window connects directly to the PS
# GP port, so no AXI Interconnect is instantiated.
#
# NOTE: fpga/ofdm_axi_lite.xdc is deliberately NOT added here. In this flow
# s_axi_aclk is driven by FCLK_CLK0 inside the block design and is no longer a
# top-level port, so its create_clock would fail to match. The PS7 IP emits its
# own clock constraint on FCLK_CLK0.
# -----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set out_dir    [file normalize [file join $repo_root ofdm_bd]]

set part_name  xc7z020clg484-1
set fclk_mhz   50

# PS7 address window for M_AXI_GP0. The ofdm_axi_lite slave is placed at the
# bottom of this window, so its base will be 0x43C00000 unless assign_bd_address
# picks otherwise -- read the printed value, do not assume it.
set gp_base    0x43C00000

puts "=== ofdm build_bd ==="
puts "repo     : $repo_root"
puts "out      : $out_dir"
puts "part     : $part_name"
puts "FCLK_CLK0: $fclk_mhz MHz"

file delete -force $out_dir
create_project -in_memory -part $part_name
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# ---------------------------------------------------------------- sources ----
# full.v is an `include aggregator for src/, so it is the only RTL file needed
# for the transmit chain.
add_files -norecurse [file join $repo_root full.v]
add_files -norecurse [file join $repo_root fpga ofdm_axi_lite.v]
set_property include_dirs [list $repo_root] [get_filesets sources_1]
update_compile_order -fileset sources_1

# ------------------------------------------------------------ block design ----
create_bd_design "ofdm_system"

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

set_property -dict [list \
  CONFIG.PCW_USE_FABRIC_INTERRUPT         {0} \
  CONFIG.PCW_IRQ_F2P_INTR                 {0} \
  CONFIG.PCW_USE_S_AXI_ACP                {0} \
  CONFIG.PCW_USE_S_AXI_GP0                {0} \
  CONFIG.PCW_USE_S_AXI_GP1                {0} \
  CONFIG.PCW_USE_S_AXI_GP2                {0} \
  CONFIG.PCW_USE_M_AXI_GP0                {1} \
  CONFIG.PCW_M_AXI_GP0_DATA_WIDTH         {32} \
  CONFIG.PCW_USE_FCLK_CLK0                {1} \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ     $fclk_mhz \
  CONFIG.PCW_USE_FCLK_RESET0_N            {1} \
  CONFIG.PCW_FPGA0_ENABLE_PERIPHERAL_RESET {1} \
  ] [get_bd_cells processing_system7_0]

# Wrap the hand-written AXI wrapper as a module reference so the BD can use it.
# Vivado 2025.1 has no make_module_reference; create_bd_cell -type module is the
# supported spelling. update_compile_order first so the HDL is elaborated before
# the module is referenced by name.
set axi_file [get_files -of_objects [get_filesets sources_1] -filter {NAME =~ "*ofdm_axi_lite.v"}]
update_compile_order -fileset sources_1
create_bd_cell -type module -reference ofdm_axi_lite ofdm_axi_lite_0

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/processing_system7_0/M_AXI_GP0" Slave "/ofdm_axi_lite_0/S_AXI" Clk "Auto"} \
  [get_bd_intf_pins ofdm_axi_lite_0/S_AXI]

# FCLK_RESET0_N is an active-low reset; tie it straight to the wrapper input.
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
               [get_bd_pins ofdm_axi_lite_0/s_axi_aresetn]

validate_bd_design

# ---------------------------------------------------------------- addresses ---
# Pin the slave to the bottom of the GP window so the software base address is
# predictable, then report what was actually assigned.
set gp_space [get_bd_addr_spaces processing_system7_0/Data]
if {[llength $gp_space] == 0} {
  error "PS7 Data address space not found; M_AXI_GP0 may not be enabled."
}
set gp_seg [get_bd_addr_segs -of_objects $gp_space -filter {NAME =~ "*M_AXI_GP0*"}]
assign_bd_address

if {[llength $gp_seg] > 0} {
  set_property range 4K $gp_seg
  set_property offset $gp_base $gp_seg
  puts "INFO: forced M_AXI_GP0 window to $gp_base (4K)"
}

open_bd_design
assign_bd_address
report_bd_address

set seg [get_bd_addr_segs -of_objects $gp_space -filter {NAME =~ "*ofdm_axi_lite_0/Reg*"}]
if {[llength $seg] == 0} {
  set seg [get_bd_addr_segs -of_objects $gp_space -filter {NAME =~ "*ofdm_axi_lite*"}]
}
if {[llength $seg] > 0} {
  set actual [get_property offset [lindex $seg 0]]
  puts ""
  puts "############################################################"
  puts "#  OFDM_BASE = [format 0x%08X $actual]"
  puts "#  Set this in fpga/main.c (currently 0x43C00000U)."
  puts "############################################################"
  puts ""
}

# ------------------------------------------------------------------ wrapper ---
make_wrapper -files [get_files ${ofdm_system}_wrapper.v] -top
add_files -norecurse [get_files ${ofdm_system}_wrapper.v]
update_compile_order -fileset sources_1

set_property top ${ofdm_system}_wrapper [get_filesets sources_1]
generate_target all [get_files ${ofdm_system}_wrapper.v]

# ----------------------------------------------------------------- finalize ---
# Strategy names vary between Vivado releases; fall back silently if absent.
foreach run [list synth_1 impl_1] {
  if {[catch {set_property strategy {Performance_ExplorePostRoutePhysOpt} [get_runs $run]} msg]} {
    puts "INFO: strategy not set on $run ($msg)"
  }
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
  puts "=== IMPLEMENTATION DID NOT REACH 100% - see the run log ==="
}

open_run impl_1
report_utilization           -file [file join $out_dir utilization.rpt]
report_timing_summary        -file [file join $out_dir timing_summary.rpt]
report_drc                   -file [file join $out_dir drc.rpt]

puts ""
puts "=== timing summary ==="
puts [get_property SLACK [get_timing_paths -max_paths 1 -setup ]]
puts "reports written to $out_dir"
puts "=== DONE ==="