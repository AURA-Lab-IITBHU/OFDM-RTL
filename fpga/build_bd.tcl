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
# NOTE: fpga/ofdm_axi_lite.xdc is deliberately NOT added here: s_axi_aclk is
# driven by FCLK_CLK0 inside the block design, so it is not a top-level port.
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
# Board Manager (GUI) installs board files into the per-user Vivado Store
# (%APPDATA%\Xilinx\Vivado\<ver>\xhub\board_store\...), not into the Vivado
# installation tree, and batch mode does not scan that location on its own --
# which is why get_board_parts came back empty. Point board.repoPaths at every
# store we can find, globbing for the directory names rather than hardcoding.
#
# Note this is a *discovery* fix, not an install fix: it makes board files that
# Board Manager has already downloaded visible to batch mode. If you have never
# run Tools -> Board Manager, there is nothing here to find.
set appdata      [file normalize $::env(APPDATA)]
set store_parent [file join $appdata "Xilinx" "Vivado"]
set vivado_ver   [version -short]
set store_root   [file join $store_parent $vivado_ver]

# Candidate board repo roots. Board Manager has used both "xhub" and
# "xhubStore_<uuid>" directory names, and the per-user store sits beside the
# Vivado installation rather than inside it, so probe each shape and keep
# whatever is really there instead of assuming one layout.
set candidates [list \
  [file join $store_root "xhub" "board_store" "xilinx_board_store" \
                       "XilinxBoardStore" "Vivado" $vivado_ver "boards"] \
  [file join $store_root "data" "boards"] \
  [file join $store_root "xhub" "data" "boards"] \
  [file join $store_root "xhub" "xhubStore" "data" "boards"] \
]
foreach store [glob -nocomplain [file join $store_root "xhubStore_*"]] {
  lappend candidates [file join $store "data" "boards"]
}
foreach store [glob -nocomplain [file join $store_root "xhub" "xhubStore_*"]] {
  lappend candidates [file join $store "data" "boards"]
}

set repo_paths {}
foreach c $candidates {
  if {[file isdirectory $c] && [lsearch -exact $repo_paths $c] < 0} {
    lappend repo_paths $c
  }
}
if {[llength $repo_paths] > 0} {
  set_param board.repoPaths $repo_paths
  puts "INFO: board.repoPaths = $repo_paths"
} else {
  puts "INFO: no board dir found under $store_root"
  puts "INFO: run Tools -> Board Manager in the Vivado GUI first, or get_board_parts stays empty"
}

file delete -force $out_dir
create_project ofdm_bd $out_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# Automatic compile order is REQUIRED for create_bd_cell -type module.
set_property source_mgmt_mode All [current_project]

# If the ZedBoard board files are installed, use them so the PS7 gets the right
# DDR/MIO configuration (needed for the FSBL to boot on real hardware).
set use_preset 0
set zb [get_board_parts -quiet *zedboard*]
if {[llength $zb] > 0} {
  # Pin a specific revision instead of taking lindex 0, which is whichever
  # version happens to sort first and changes if Board Manager fetches another.
  set zb_pick [lsearch -exact $zb avnet.com:zedboard:1.4]
  if {$zb_pick < 0} { set zb_pick 0 }
  set zb_sel [lindex $zb $zb_pick]
  set_property board_part $zb_sel [current_project]
  set use_preset 1
  puts "INFO: using board part $zb_sel"
  if {[llength $zb] > 1} {
    puts "INFO: other zedboard board parts available: $zb"
  }
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

# Every `include'd file must be in the project for module references to
# resolve (filemgmt 56-591). Add them as Verilog Header so they are NOT
# compiled standalone; they only get pulled in through full.v, which avoids
# duplicate-module errors. uart_rx.v is included by full.v too.
set src_files [glob -nocomplain [file join $repo_root src *.v]]
add_files -norecurse -fileset sources_1 $src_files
foreach f $src_files {
  set_property file_type {Verilog Header} [get_files $f]
}
update_compile_order -fileset sources_1

# ------------------------------------------------------------ block design ----
create_bd_design $bd_name

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Board preset (if available) + external DDR / FIXED_IO ports.
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
  -config [list make_external "FIXED_IO, DDR" apply_board_preset $use_preset \
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

# Wrap the hand-written AXI wrapper as a module reference.
update_compile_order -fileset sources_1
create_bd_cell -type module -reference ofdm_axi_lite ofdm_axi_lite_0

# Interface name is inferred from the s_axi_* port prefix: lowercase "s_axi".
# Automation adds the interconnect and a proc_sys_reset, and wires clock and
# reset (including s_axi_aresetn) itself, so no manual connect_bd_net here.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config {Master "/processing_system7_0/M_AXI_GP0" Slave "/ofdm_axi_lite_0/s_axi" Clk "Auto"} \
  [get_bd_intf_pins ofdm_axi_lite_0/s_axi]

# ---------------------------------------------------------------- addresses ---
# Zynq-7000 GP0 is hardwired to 0x4000_0000-0x7FFF_FFFF in silicon and Vivado
# does not expose the GP master aperture as a movable segment -- there is
# nothing to pin on the master side, and 0x43C00000 sits inside GP0 regardless
# of what assign_bd_address chose. So pin the SLAVE segment directly in the PS7
# Data space.
assign_bd_address

set gp_space [get_bd_addr_spaces processing_system7_0/Data]
set seg [get_bd_addr_segs -of_objects $gp_space -filter {NAME =~ "*ofdm_axi_lite*"}]

if {[llength $seg] == 0} {
  puts "=== address segments present (diagnostic) ==="
  foreach s [get_bd_addr_segs] {
    puts "  SEG [get_property NAME $s] offset=[get_property offset $s] range=[get_property range $s]"
  }
  error "ofdm_axi_lite address segment not found."
}

set target_seg [lindex $seg 0]

# Shrink the range before moving the offset, so an intermediate wide range can
# never transiently overlap another segment.
if {[catch {
  set_property range  4K       $target_seg
  set_property offset $gp_base $target_seg
} msg]} {
  puts "WARNING: could not pin ofdm_axi_lite to $gp_base ($msg); using assigned value"
}

set actual [get_property offset $target_seg]
puts ""
puts "############################################################"
puts "#  OFDM_BASE = $actual"
puts "#  segment   = [get_property NAME $target_seg]"
puts "#  range     = [get_property range $target_seg]"
puts "#  Set this in fpga/main.c (currently 0x43C00000U)."
puts "############################################################"
puts ""

puts "=== address segments in /processing_system7_0/Data ==="
foreach s [get_bd_addr_segs -of_objects $gp_space] {
  puts "SEG [get_property NAME $s] offset=[get_property offset $s] range=[get_property range $s]"
}

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