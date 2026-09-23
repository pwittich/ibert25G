set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists isolated_smoke]} { set isolated_smoke 0 }
set project_name [expr {[info exists project_name_override]
  ? $project_name_override
  : ($isolated_smoke ? "gt_test_milestone25" : "gt_test_milestone3")}]
set bd_name gt_test_milestone3_bd
set project_dir [file join $repo_dir build $project_name]
set firmware_elf [expr {[info exists firmware_elf_override]
  ? $firmware_elf_override
  : [file join $repo_dir build firmware gt_test_milestone3.elf]}]
if {!$isolated_smoke && ![info exists top_generics_override]} {
  # Full Milestone 3 v12 preserves v11 acquisition and adds native per-lane
  # RXCDRLOCK to runtime lock-loss accounting. 0x0002000C = 131084.
  set top_generics_override {
    HARDWARE_VERSION=131084
    STAGED_RX_ACQUISITION=1
    REQUIRE_ERROR_FREE_QUALIFICATION=0
  }
}

# A candidate build must not inherit run products or generated IP metadata
# from the previous version.  Only generated build output is removed; source,
# checked-in XCI files, firmware input, and historical documentation remain.
if {[file exists $project_dir]} { file delete -force $project_dir }
create_project $project_name $project_dir \
  -part xcvu13p-flga2577-2-e -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set source_files [list \
  [file join $repo_dir src clock_input_buffers.sv] \
  [file join $repo_dir src isolated_refclk_buffers.sv] \
  [file join $repo_dir src clock_frequency_monitor.sv] \
  [file join $repo_dir src i2c_register_slave.sv] \
  [file join $repo_dir src sysmon_i2c_ssi.sv] \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir src gt_transition_trace.sv] \
  [file join $repo_dir src gt_rx_error_profile.sv] \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir src axi_lite_gt_test_engine.sv] \
  [file join $repo_dir src gt_quad_controller.sv] \
  [file join $repo_dir src gt_runtime_integrity_monitor.sv] \
  [file join $repo_dir src gt_prbs_test_controller.sv] \
  [file join $repo_dir src managed_quad124_lane_reset_policy.sv] \
  [file join $repo_dir src managed_quad124_wrapper.sv] \
  [file join $repo_dir src managed_native_left_quad_wrapper.sv] \
  [file join $repo_dir src managed_firefly1_group_wrapper.sv] \
  [file join $repo_dir src gt_test_milestone3_top.sv]]
if {!$isolated_smoke} {
  lappend source_files \
    [file join $repo_dir src ibert_ultrascale_gty_r.vhd] \
    [file join $repo_dir src ibert_left_milestone3_wrapper.sv] \
    [file join $repo_dir src ibert_milestone3_top.sv]
} else {
  lappend source_files [file join $repo_dir src gt_test_milestone25_top.sv]
  if {[info exists top_name_override] && $top_name_override eq "gt_test_firefly1_loopback_v2_top"} {
    lappend source_files [file join $repo_dir src gt_test_firefly1_loopback_v2_top.sv]
  }
}
add_files $source_files
if {[info exists firefly1_functional] && $firefly1_functional} {
  source [file join $script_dir derive_native_left121_123_functional_topology.tcl]
  set native_ip_dir [file join $repo_dir build gt_native_left121_123_functional_ip_v1 gt_native_left121_123_functional_ip.gen sources_1 ip]
  foreach quad {121 122 123} {
    set d [file join $native_ip_dir native_left${quad}_functional_gt synth]
    foreach f [list native_left${quad}_functional_gt_gtye4_channel_wrapper.v native_left${quad}_functional_gt_gtye4_common_wrapper.v native_left${quad}_functional_gt_gtwizard_gtye4.v native_left${quad}_functional_gt_gtwizard_top.v native_left${quad}_functional_gt_topology.v] { add_files -norecurse [file join $d $f] }
    # These Wizard-owned constraints bind each functional core to its documented
    # q121--q123 sites.  The topology wrapper is source-controlled; the XDC
    # remains generated alongside its owning Wizard.
    add_files -fileset constrs_1 -norecurse [file join $d native_left${quad}_functional_gt.xdc]
  }
  set d [file join $native_ip_dir native_left121_functional_gt synth]
  foreach f {gtwizard_ultrascale_v1_7_gtye4_channel.v gtwizard_ultrascale_v1_7_gtye4_common.v} { add_files -norecurse [file join $d $f] }
  foreach f [glob -nocomplain [file join $native_ip_dir native_left121_functional_gt hdl *.v]] { add_files -norecurse $f }
}

if {!$isolated_smoke} {
  add_files -fileset utils_1 -norecurse \
    [file join $script_dir apply_ibert_floorplan_milestone3.tcl]
}

if {!$isolated_smoke} {
  import_ip -files [list \
    [file join $repo_dir ip ibert_left ibert_ultrascale_gty_core_l.xci] \
    [file join $repo_dir ip ibert_right ibert_ultrascale_gty_core_r.xci]]
  set left_ibert [get_ips ibert_ultrascale_gty_core_l]
  set_property -dict [list \
    CONFIG.C_PROTOCOL_QUAD_COUNT_1 {13} \
    CONFIG.C_PROTOCOL_QUAD4 {None} \
    CONFIG.C_REFCLK_SOURCE_QUAD_4 {None} \
    CONFIG.C_SYSCLOCK_SOURCE_INT {QUAD122_0}] $left_ibert
  if {[get_property CONFIG.C_PROTOCOL_QUAD_COUNT_1 $left_ibert] ne "13" ||
      [get_property CONFIG.C_PROTOCOL_QUAD4 $left_ibert] ne "None"} {
    error "Milestone 3 must remove physical quad 124 from the left IBERT core"
  }
}

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
  -version 1.7 -module_name managed_quad124_gt
set managed_gt [get_ips managed_quad124_gt]
set_property -dict [list \
  CONFIG.CHANNEL_ENABLE {X0Y16 X0Y17 X0Y18 X0Y19} \
  CONFIG.TX_LINE_RATE {25.78125} \
  CONFIG.RX_LINE_RATE {25.78125} \
  CONFIG.TX_REFCLK_FREQUENCY {322.265625} \
  CONFIG.RX_REFCLK_FREQUENCY {322.265625} \
  CONFIG.INS_LOSS_NYQ {3} \
  CONFIG.TX_PLL_TYPE {QPLL0} \
  CONFIG.RX_PLL_TYPE {QPLL0} \
  CONFIG.TX_USER_DATA_WIDTH {80} \
  CONFIG.RX_USER_DATA_WIDTH {80} \
  CONFIG.TX_INT_DATA_WIDTH {80} \
  CONFIG.RX_INT_DATA_WIDTH {80} \
  CONFIG.TX_MASTER_CHANNEL {X0Y16} \
  CONFIG.RX_MASTER_CHANNEL {X0Y16} \
  CONFIG.FREERUN_FREQUENCY {200} \
  CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
  CONFIG.LOCATE_COMMON {CORE} \
  CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
  CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
  CONFIG.ENABLE_OPTIONAL_PORTS {
    drpaddr_in drpclk_in drpdi_in drpdo_out drpen_in drprdy_out drpwe_in
    loopback_in qpll0lock_out rxcdrlock_out rxpmareset_in rxprbscntreset_in
    rxprbserr_out rxprbslocked_out rxprbssel_in rxresetdone_out txprbsforceerr_in
    txprbssel_in txresetdone_out
  }] $managed_gt
if {[get_property CONFIG.INS_LOSS_NYQ $managed_gt] ne "3"} {
  error "Managed quad must match the golden IBERT 3-dB insertion-loss setting"
}

set board_constraint [expr {[info exists board_constraint_override]
  ? $board_constraint_override
  : ($isolated_smoke
    ? [file join $repo_dir constraints gt_test_milestone25_board.xdc]
    : [file join $repo_dir constraints board_pins.xdc])}]
set constraint_files [list \
  $board_constraint \
  [file join $repo_dir constraints sysmon.xdc] \
  [file join $repo_dir constraints clock_monitor_pins.xdc] \
  [file join $repo_dir constraints clock_monitor_cdc.xdc] \
  [file join $repo_dir constraints gt_test_milestone3.xdc]]
if {!$isolated_smoke} {
  lappend constraint_files \
    [file join $repo_dir constraints ibert_left_timing.xdc] \
    [file join $repo_dir constraints ibert_right_timing.xdc]
}
add_files -fileset constrs_1 $constraint_files

# Recreate the same small supervisor subsystem used by Milestone 2.
create_bd_design $bd_name
set clk [create_bd_port -dir I -type clk -freq_hz 200000000 clk_200]
set reset [create_bd_port -dir I -type rst reset]
set_property CONFIG.POLARITY ACTIVE_HIGH $reset
set engine_interrupt [create_bd_port -dir I -type intr engine_interrupt]
set mb [create_bd_cell -type ip \
  -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {
  axi_intc {1} axi_periph {Enabled} cache {None} clk {/clk_200}
  debug_module {Debug Only} ecc {None} local_mem {32KB} preset {None}
} $mb
set_property -dict [list CONFIG.C_USE_MSR_INSTR {1} CONFIG.C_USE_BARREL {1} \
  CONFIG.C_USE_INTERRUPT {1} CONFIG.C_ENABLE_DISCRETE_PORTS {1}] $mb

set mb_interrupt_intf [get_bd_intf_pins $mb/INTERRUPT]
set mb_interrupt_net [get_bd_intf_nets -of_objects $mb_interrupt_intf]
disconnect_bd_intf_net $mb_interrupt_net $mb_interrupt_intf
set intc_axi_pin [get_bd_intf_pins microblaze_0_axi_intc/s_axi]
set intc_axi_net [get_bd_intf_nets -of_objects $intc_axi_pin]
disconnect_bd_intf_net $intc_axi_net \
  [get_bd_intf_pins microblaze_0_axi_periph/M00_AXI]
set intc_intr_net [get_bd_nets -of_objects \
  [get_bd_pins microblaze_0_xlconcat/dout]]
delete_bd_objs $mb_interrupt_net $intc_axi_net $intc_intr_net
delete_bd_objs [get_bd_cells microblaze_0_xlconcat]
delete_bd_objs [get_bd_cells microblaze_0_axi_intc]
connect_bd_net $engine_interrupt [get_bd_pins $mb/Interrupt]

set wakeup_concat [create_bd_cell -type ip \
  -vlnv xilinx.com:ip:xlconcat:2.1 microblaze_0_wakeup_concat]
set_property CONFIG.NUM_PORTS 2 $wakeup_concat
connect_bd_net $engine_interrupt [get_bd_pins $wakeup_concat/In0]
connect_bd_net [get_bd_pins $mb/Dbg_Wakeup] [get_bd_pins $wakeup_concat/In1]
connect_bd_net [get_bd_pins $wakeup_concat/dout] [get_bd_pins $mb/Wakeup]

set axi_periph [get_bd_cells microblaze_0_axi_periph]
set_property CONFIG.NUM_MI 1 $axi_periph
make_bd_intf_pins_external [get_bd_intf_pins $axi_periph/M00_AXI]
set engine_axi [get_bd_intf_ports -quiet -filter {NAME =~ M00_AXI*}]
if {[llength $engine_axi] != 1} { error "Expected one external AXI interface" }
set_property name M_AXI_ENGINE $engine_axi
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} CONFIG.ADDR_WIDTH {32} \
  CONFIG.DATA_WIDTH {32} CONFIG.FREQ_HZ {200000000}] \
  [get_bd_intf_ports M_AXI_ENGINE]
connect_bd_net $reset [get_bd_pins rst_clk_200_200M/ext_reset_in]
assign_bd_address
set engine_seg [get_bd_addr_segs -quiet microblaze_0/Data/SEG_M_AXI_ENGINE_Reg]
set_property offset 0x44A00000 $engine_seg
set_property range 4K $engine_seg
validate_bd_design
save_bd_design
set bd_file [get_files ${bd_name}.bd]
generate_target all $bd_file
set wrapper [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper

if {![file exists $firmware_elf]} {
  error "Milestone-3 firmware missing; run scripts/build_milestone3_firmware.sh"
}
add_files -fileset sources_1 -norecurse $firmware_elf
set_property SCOPED_TO_REF $bd_name [get_files [file tail $firmware_elf]]
set_property SCOPED_TO_CELLS microblaze_0 [get_files [file tail $firmware_elf]]

set required_ips [list $managed_gt]
if {!$isolated_smoke} {
  set required_ips [concat [list $left_ibert \
    [get_ips ibert_ultrascale_gty_core_r]] $required_ips]
}
foreach ip $required_ips {
  if {[get_property IS_LOCKED $ip]} { error "$ip is locked" }
}
if {!$isolated_smoke} {
  generate_target all $left_ibert
  generate_target all [get_ips ibert_ultrascale_gty_core_r]
}
generate_target all $managed_gt
if {!$isolated_smoke} {
  source [file join $script_dir configure_ibert_floorplan_milestone3.tcl]
}
set top_name [expr {[info exists top_name_override]
  ? $top_name_override
  : ($isolated_smoke ? "gt_test_milestone25_top" : "gt_test_milestone3_top")}]
set_property top $top_name [get_filesets sources_1]
if {[info exists top_generics_override]} {
  set_property generic $top_generics_override [get_filesets sources_1]
}
update_compile_order -fileset sources_1
puts "Created $project_name project: [get_property DIRECTORY [current_project]]"
