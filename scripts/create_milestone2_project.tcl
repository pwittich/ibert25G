set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_milestone2]
set firmware_elf [file join $repo_dir build firmware gt_test_milestone2.elf]

create_project gt_test_milestone2 $project_dir \
  -part xcvu13p-flga2577-2-e -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files [list \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir src axi_lite_gt_test_engine.sv] \
  [file join $repo_dir src i2c_register_slave.sv] \
  [file join $repo_dir src gt_test_engine_shell.sv] \
  [file join $repo_dir src gt_test_hardware_shell.sv] \
  [file join $repo_dir src gt_test_milestone2_top.sv]]
add_files -fileset constrs_1 \
  [file join $repo_dir constraints gt_test_milestone2.xdc]

create_bd_design gt_test_milestone2_bd
set clk [create_bd_port -dir I -type clk -freq_hz 200000000 clk_200]
set reset [create_bd_port -dir I -type rst reset]
set_property CONFIG.POLARITY ACTIVE_HIGH $reset
set engine_interrupt [create_bd_port -dir I -type intr engine_interrupt]

set mb [create_bd_cell -type ip \
  -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {
  axi_intc {1}
  axi_periph {Enabled}
  cache {None}
  clk {/clk_200}
  debug_module {Debug Only}
  ecc {None}
  local_mem {32KB}
  preset {None}
} $mb

# The bare-metal supervisor uses MSRSET/MSRCLR for interrupt control and the
# SLEEP instruction while the HDL engine owns the active job.  Match the
# compiler's barrel-shifter target as well.
set_property -dict [list \
  CONFIG.C_USE_MSR_INSTR {1} \
  CONFIG.C_USE_BARREL {1} \
  CONFIG.C_USE_INTERRUPT {1} \
  CONFIG.C_ENABLE_DISCRETE_PORTS {1}] $mb

# MicroBlaze automation creates an AXI interrupt controller and concat block.
# Milestone 2 has exactly one level-sensitive source, so remove that unnecessary
# layer and drive the processor's standard fixed-vector interrupt directly.
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

# SLEEP halts the MicroBlaze pipeline until a Wakeup input is asserted. Feed
# the level interrupt into Wakeup[0] so the same event both wakes the processor
# and enters the standard interrupt vector. Preserve debugger wake on bit 1.
set wakeup_concat [create_bd_cell -type ip \
  -vlnv xilinx.com:ip:xlconcat:2.1 microblaze_0_wakeup_concat]
set_property CONFIG.NUM_PORTS 2 $wakeup_concat
connect_bd_net $engine_interrupt [get_bd_pins $wakeup_concat/In0]
connect_bd_net [get_bd_pins $mb/Dbg_Wakeup] \
  [get_bd_pins $wakeup_concat/In1]
connect_bd_net [get_bd_pins $wakeup_concat/dout] \
  [get_bd_pins $mb/Wakeup]

set axi_periph [get_bd_cells microblaze_0_axi_periph]
set_property CONFIG.NUM_MI 1 $axi_periph

make_bd_intf_pins_external [get_bd_intf_pins $axi_periph/M00_AXI]
set engine_axi [get_bd_intf_ports -quiet -filter {NAME =~ M00_AXI*}]
if {[llength $engine_axi] != 1} {
  error "Expected one external AXI engine interface"
}
set_property name M_AXI_ENGINE $engine_axi
set_property -dict [list \
  CONFIG.PROTOCOL {AXI4LITE} \
  CONFIG.ADDR_WIDTH {32} \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.FREQ_HZ {200000000}] [get_bd_intf_ports M_AXI_ENGINE]
connect_bd_net $reset [get_bd_pins rst_clk_200_200M/ext_reset_in]

assign_bd_address
set engine_seg [get_bd_addr_segs -quiet \
  microblaze_0/Data/SEG_M_AXI_ENGINE_Reg]
if {[llength $engine_seg] != 1} {
  error "Expected one test-engine processor address segment"
}
set_property offset 0x44A00000 $engine_seg
set_property range 4K $engine_seg

validate_bd_design
if {[get_property CONFIG.C_USE_INTERRUPT $mb] ne "1"} {
  error "MicroBlaze must use the standard fixed-vector interrupt mode"
}
if {[get_property CONFIG.C_ENABLE_DISCRETE_PORTS $mb] ne "1"} {
  error "MicroBlaze Wakeup ports must be enabled for the SLEEP instruction"
}
if {[llength [get_bd_cells -quiet microblaze_0_axi_intc]] != 0} {
  error "The single engine interrupt must connect directly to MicroBlaze"
}
save_bd_design
set bd_file [get_files gt_test_milestone2_bd.bd]
generate_target all $bd_file
set wrapper [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper

if {[file exists $firmware_elf]} {
  add_files -fileset sources_1 -norecurse $firmware_elf
  set_property SCOPED_TO_REF gt_test_milestone2_bd \
    [get_files [file tail $firmware_elf]]
  set_property SCOPED_TO_CELLS microblaze_0 \
    [get_files [file tail $firmware_elf]]
  puts "Embedded firmware: $firmware_elf"
} else {
  puts "WARNING: firmware ELF not found; run scripts/build_milestone2_firmware.sh"
}

set_property top gt_test_milestone2_top [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "Created milestone-2 project: [get_property DIRECTORY [current_project]]"
