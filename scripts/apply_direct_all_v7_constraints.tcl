# Apply the canonical board pin database except the FireFly data lanes.  The
# all-direct image retains those ports only for source-interface reuse and
# deliberately does not instantiate their GTs.  This implementation pre-hook
# is ordinary Tcl (unlike XDC's restricted command interpreter), so it can
# perform an exact line projection while retaining board_pins.xdc as the sole
# pin authority.
set direct_all_v7_script_dir [file dirname [file normalize [info script]]]
set direct_all_v7_repo_dir [file dirname $direct_all_v7_script_dir]
set direct_all_v7_board [file join $direct_all_v7_repo_dir constraints board_pins.xdc]
set direct_all_v7_channel [open $direct_all_v7_board r]
set direct_all_v7_contents [read $direct_all_v7_channel]
close $direct_all_v7_channel
set direct_all_v7_applied 0
set direct_all_v7_skipped_firefly 0
foreach direct_all_v7_line [split $direct_all_v7_contents "\n"] {
  if {[regexp {_ff[1-6]_(recv|xmit)} $direct_all_v7_line]} {
    incr direct_all_v7_skipped_firefly
    continue
  }
  if {[string trim $direct_all_v7_line] eq "" ||
      [string match "#*" [string trimleft $direct_all_v7_line]]} {continue}
  uplevel #0 $direct_all_v7_line
  incr direct_all_v7_applied
}
if {$direct_all_v7_skipped_firefly != 224} {
  error "Canonical board projection skipped $direct_all_v7_skipped_firefly FireFly constraints, expected 224"
}
puts "DIRECT_ALL_V7_BOARD: applied $direct_all_v7_applied canonical non-FireFly constraints; skipped $direct_all_v7_skipped_firefly FireFly constraints"

# Bounds and clock-domain exceptions for fourteen independent managed quads.
set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 224} {error "Expected 224 all-direct descriptor endpoints, got [llength $descriptors]"}
set rx_clocks {}
for {set q 0} {$q < 14} {incr q} {
  set qdesc {}
  for {set lane [expr {56 + 4*$q}]} {$lane < 60 + 4*$q} {incr lane} {
    set marker [format {g_lane[%d].g_managed.u_lane/} $lane]
    foreach p $descriptors {
      if {[string first $marker [get_property NAME $p]] >= 0} {lappend qdesc $p}
    }
  }
  if {[llength $qdesc] != 16} {error "Quad index $q descriptor count is [llength $qdesc]"}
  set clock_pins {}
  foreach p $qdesc {lappend clock_pins [get_pins [get_property PARENT_CELL $p]/C]}
  set qclocks [get_clocks -quiet -of_objects $clock_pins]
  if {[llength $qclocks] != 1} {error "Quad index $q has [llength $qclocks] RX descriptor clocks"}
  lappend rx_clocks [lindex $qclocks 0]
  set sources [all_fanin -flat -startpoints_only -to $qdesc]
  set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $qdesc
  set_bus_skew 3.000 -from $sources -to $qdesc
}
set session_pins [get_pins -hier -filter {
  NAME =~ *u_managed_direct/session_meta_reg/C ||
  NAME =~ *u_managed_direct/session_sync_reg/C}]
if {[llength $session_pins] != 28} {error "Expected 28 TX session synchronizer clock pins, got [llength $session_pins]"}
set tx_meta [get_pins -hier -filter {
  NAME =~ *g_prbs_control*.txsel_meta_reg*/D ||
  NAME =~ *g_prbs_control*.loopback_meta_reg*/D ||
  NAME =~ *g_prbs_control*.inject_meta_reg/D}]
# txsel_meta[3] has a constant-zero source and is correctly removed, leaving
# three PRBS-select, three loopback, and one injection first stage per lane.
if {[llength $tx_meta] != 392} {error "Expected 392 implemented TX-domain first-stage CDC pins, got [llength $tx_meta]"}
set tx_clock_pins {}
foreach p $tx_meta {lappend tx_clock_pins [get_pins [get_property PARENT_CELL $p]/C]}
set tx_clocks [lsort -unique [concat [get_clocks -quiet -of_objects $tx_clock_pins] \
  [get_clocks -quiet -of_objects $session_pins]]]
if {[llength $rx_clocks] != 14 || [llength $tx_clocks] != 14} {
  error "Expected fourteen RX and TX native clocks, got [llength $rx_clocks]/[llength $tx_clocks]"
}
set native_clocks [lsort -unique [concat $rx_clocks $tx_clocks]]
set other_clocks {}
foreach c [get_clocks] {if {[lsearch -exact $native_clocks $c] < 0} {lappend other_clocks $c}}
# The GT PRBS controls are asynchronous dynamic controls.  Enumerate only the
# legal hard-macro endpoints that produced the bogus 7-ps RXOUTCLK paths in
# the rejected first route. Bit 3 of RXPRBSSEL is tied off by this Wizard and
# is not a timing endpoint.
set native_gt_prbs_controls [get_pins -hier -quiet -filter {
  REF_PIN_NAME == RXPRBSCNTRESET || REF_PIN_NAME == RXPRBSSEL[0] ||
  REF_PIN_NAME == RXPRBSSEL[1] || REF_PIN_NAME == RXPRBSSEL[2]}]
if {[llength $native_gt_prbs_controls] != 224} {
  error "Expected 224 native GT PRBS control pins, got [llength $native_gt_prbs_controls]"
}
set_false_path -from $other_clocks -to $native_gt_prbs_controls
# Every lane-engine first-stage synchronizer is an intentional CDC endpoint.
# Keep the selected/PRBS descriptor stages in their independently bounded
# max-delay/bus-skew collection above, and enumerate every other lane stage
# exactly.  There are six scalar stages per managed lane: start, stop, lock,
# CDR lock, measurement enable, and controls enable.
set rx_all_meta [get_pins -hier -quiet -filter {
  NAME =~ */g_lane*.g_managed.u_lane/*_meta_reg*/D}]
if {[llength $rx_all_meta] != 560} {
  error "Expected 560 total lane-engine first stages, got [llength $rx_all_meta]"
}
set rx_other_meta {}
foreach p $rx_all_meta {
  if {[lsearch -exact $descriptors $p] < 0} {lappend rx_other_meta $p}
}
if {[llength $rx_other_meta] != 336} {
  error "Expected 336 non-descriptor lane first stages, got [llength $rx_other_meta]"
}
# Each quad reset policy separately samples management-domain quad_ready into
# its RX clock domain.  Select only stage zero; stage one is synchronous.
set reset_ready_meta {}
foreach p [get_pins -hier -quiet -filter {
    NAME =~ *u_lane_reset_policy/ready_sync_reg*/D}] {
  if {[regexp {ready_sync_reg\[0\]/D$} [get_property NAME $p]]} {
    lappend reset_ready_meta $p
  }
}
if {[llength $reset_ready_meta] != 14} {
  error "Expected 14 reset-policy ready first stages, got [llength $reset_ready_meta]"
}
set session_meta_d [get_pins -hier -quiet -filter {
  NAME =~ *u_managed_direct/session_meta_reg/D}]
if {[llength $session_meta_d] != 14} {
  error "Expected 14 TX session first stages, got [llength $session_meta_d]"
}
set_false_path -from $other_clocks -to [concat $rx_other_meta $reset_ready_meta $tx_meta $session_meta_d]

# Recovery/removal on the asynchronous pins of native-domain fabric flops is
# intentionally excluded; deassertion is synchronized by the corresponding
# two-stage chains. Filter out GT hard macros, whose many async-looking pins
# are not legal timing endpoints.
set native_async_fabric_pins {}
foreach pin [all_registers -clock $native_clocks -async_pins] {
  set parent [get_cells -quiet [get_property PARENT_CELL $pin]]
  if {[llength $parent] == 1 &&
      ([string match "FD*" [get_property REF_NAME $parent]] ||
       [string match "LD*" [get_property REF_NAME $parent]])} {
    lappend native_async_fabric_pins $pin
  }
}
if {[llength $native_async_fabric_pins] < 100} {
  error "Native fabric async-pin inventory unexpectedly small: [llength $native_async_fabric_pins]"
}
set_false_path -to $native_async_fabric_pins
set_false_path -from $native_clocks -to $other_clocks
set_false_path -from $rx_clocks -to $tx_clocks
set_false_path -from $tx_clocks -to $rx_clocks
puts "DIRECT_ALL_V7_CDC: 224 bounded descriptor endpoints, 336 other lane first stages, 14 reset-ready stages, 392 TX first stages plus 14 session chains, fourteen 3-ns bus-skew groups"

# The all-direct engine is physically central while its handshake-qualified
# controls must reach every SLR.  Each new local control bank deliberately
# adds one registered management-clock latency; all source values remain
# stable until the aggregated acknowledgement returns.  A two-cycle setup
# requirement is therefore the functional contract for these 28 D pins.
set control_pipeline_d [get_pins -hier -quiet -filter {
  NAME =~ *u_control_pipeline/controls_out_reg*/D}]
if {[llength $control_pipeline_d] != 28} {
  error "Expected 28 SLR-local control-pipeline D pins, got [llength $control_pipeline_d]"
}
set_multicycle_path 2 -setup -to $control_pipeline_d
set_multicycle_path 1 -hold -to $control_pipeline_d
puts "DIRECT_ALL_V7_CONTROL: four parallel seven-bit SLR banks with two-cycle source paths"

# ST_COPY holds both its lane selector and all post-capture source records for
# a full settle cycle before loading this explicit 256-bit staging register.
# The next phase commits the staged value, so this is a functional two-cycle
# path rather than a timing-only relaxation.
set copy_record_stage_d [get_pins -hier -quiet -filter {
  NAME =~ *u_engine/u_core/copy_record_stage_reg*/D}]
if {[llength $copy_record_stage_d] != 256} {
  error "Expected 256 staged record-copy D pins, got [llength $copy_record_stage_d]"
}
set_multicycle_path 2 -setup -to $copy_record_stage_d
set_multicycle_path 1 -hold -to $copy_record_stage_d
puts "DIRECT_ALL_V7_COPY: 256-bit immutable result mux staged on a functional two-cycle path"

# Keep each quad's management/control logic with the SLR containing its four
# fixed GT channels. The unconstrained first route placed q234 controller
# replicas in SLR1/2 and its TX-domain consumers in SLR3, producing avoidable
# two-boundary CDC routes. The registered reduction stages follow the same
# physical grouping; its final four-way stage is centered in SLR1.
proc direct_all_v7_exact_named_cell {candidates wanted description} {
  set matches {}
  foreach candidate $candidates {
    if {[get_property NAME $candidate] eq $wanted} {lappend matches $candidate}
  }
  if {[llength $matches] != 1} {
    error "Expected one $description named $wanted, got [llength $matches]"
  }
  return [lindex $matches 0]
}
set direct_all_v7_wrappers [get_cells -hier -quiet -filter {
  REF_NAME =~ managed_direct_quad_v6_wrapper*}]
if {[llength $direct_all_v7_wrappers] != 14} {
  error "Expected fourteen managed wrapper hierarchy cells, got [llength $direct_all_v7_wrappers]"
}
set direct_all_v7_prbs_controllers [get_cells -hier -quiet -filter {
  REF_NAME =~ gt_prbs_test_controller* && NAME =~ *g_all_direct*}]
if {[llength $direct_all_v7_prbs_controllers] != 14} {
  error "Expected fourteen PRBS controller hierarchy cells, got [llength $direct_all_v7_prbs_controllers]"
}
# Vivado can fold the four identical hierarchy reference names even when the
# 28 physical registers are preserved.  The physical contract is the seven
# distinct launch registers per SLR, so classify and constrain those directly.
set direct_all_v7_control_registers_by_slr [list {} {} {} {}]
foreach pin $control_pipeline_d {
  set pin_name [get_property NAME $pin]
  if {![regexp {g_control_slr\[([0-3])\]} $pin_name -> slr]} {
    error "Cannot classify control-pipeline pin by SLR: $pin_name"
  }
  set cell [get_cells -quiet [get_property PARENT_CELL $pin]]
  if {[llength $cell] != 1} {error "No unique register owns $pin_name"}
  lset direct_all_v7_control_registers_by_slr $slr \
    [lsort -unique [concat [lindex $direct_all_v7_control_registers_by_slr $slr] $cell]]
}
# The 56 selected-bit plus 168 PRBS-mode descriptor launch registers are
# likewise explicit physical launch points. The 3/4/4/3 quad distribution is
# 48/64/64/48 registers across SLR0..3.
set direct_all_v7_descriptor_launch_registers_by_slr [list {} {} {} {}]
set descriptor_launch_registers [get_cells -hier -quiet -filter {
  NAME =~ *g_descriptor_launch*.g_local.*_launch_reg*}]
if {[llength $descriptor_launch_registers] != 224} {
  error "Expected 224 localized descriptor launch registers, got [llength $descriptor_launch_registers]"
}
foreach cell $descriptor_launch_registers {
  set cell_name [get_property NAME $cell]
  if {![regexp {g_descriptor_launch\[([0-9]+)\]} $cell_name -> lane] || $lane < 56 || $lane > 111} {
    error "Cannot classify descriptor launch register: $cell_name"
  }
  set slr [expr {$lane < 68 ? 0 : $lane < 84 ? 1 : $lane < 100 ? 2 : 3}]
  lset direct_all_v7_descriptor_launch_registers_by_slr $slr \
    [concat [lindex $direct_all_v7_descriptor_launch_registers_by_slr $slr] $cell]
}
for {set q 0} {$q < 14} {incr q} {
  set wrapper [direct_all_v7_exact_named_cell $direct_all_v7_wrappers \
    [format {u_all_direct/g_all_direct.g_quad[%d].u_managed_direct} $q] \
    "managed wrapper for quad index $q"]
  set slr [expr {$q < 3 ? 0 : $q < 7 ? 1 : $q < 11 ? 2 : 3}]
  set_property USER_SLR_ASSIGNMENT SLR$slr $wrapper
  set controller [direct_all_v7_exact_named_cell $direct_all_v7_prbs_controllers \
    [format {u_all_direct/g_all_direct.g_quad[%d].u_managed_direct/u_prbs_test_controller} $q] \
    "PRBS controller for quad index $q"]
  set_property USER_SLR_ASSIGNMENT SLR$slr $controller
}
for {set slr 0} {$slr < 4} {incr slr} {
  set bank_registers [lindex $direct_all_v7_control_registers_by_slr $slr]
  if {[llength $bank_registers] != 7} {
    error "Expected seven preserved control registers for SLR$slr, got [llength $bank_registers]"
  }
  set pblock_name direct_all_v7_control_slr$slr
  if {[llength [get_pblocks -quiet $pblock_name]]} {
    delete_pblocks [get_pblocks $pblock_name]
  }
  create_pblock $pblock_name
  resize_pblock [get_pblocks $pblock_name] -add SLR$slr
  add_cells_to_pblock [get_pblocks $pblock_name] $bank_registers
  set descriptor_registers [lindex $direct_all_v7_descriptor_launch_registers_by_slr $slr]
  set expected_descriptor_registers [lindex {48 64 64 48} $slr]
  if {[llength $descriptor_registers] != $expected_descriptor_registers} {
    error "Expected $expected_descriptor_registers localized descriptor registers for SLR$slr, got [llength $descriptor_registers]"
  }
  set descriptor_pblock_name direct_all_v7_descriptor_slr$slr
  if {[llength [get_pblocks -quiet $descriptor_pblock_name]]} {
    delete_pblocks [get_pblocks $descriptor_pblock_name]
  }
  create_pblock $descriptor_pblock_name
  resize_pblock [get_pblocks $descriptor_pblock_name] -add SLR$slr
  add_cells_to_pblock [get_pblocks $descriptor_pblock_name] $descriptor_registers
}
set direct_all_v7_groups [get_cells -hier -quiet -filter {
  REF_NAME =~ direct_all_v7_quad_group_aggregate*}]
if {[llength $direct_all_v7_groups] != 4} {
  error "Expected four registered group reducer hierarchy cells, got [llength $direct_all_v7_groups]"
}
for {set slr 0} {$slr < 4} {incr slr} {
  set group [direct_all_v7_exact_named_cell $direct_all_v7_groups \
    [format {u_all_direct/g_all_direct.u_quad_aggregate/g_slr%d} $slr] \
    "registered SLR$slr reducer hierarchy"]
  set_property USER_SLR_ASSIGNMENT SLR$slr $group
}
set direct_all_v7_final_candidates [get_cells -hier -quiet -filter {
  REF_NAME == direct_all_v7_quad_aggregate}]
set final_reduce [direct_all_v7_exact_named_cell $direct_all_v7_final_candidates \
  {u_all_direct/g_all_direct.u_quad_aggregate} {global quad reducer hierarchy}]
set_property USER_SLR_ASSIGNMENT SLR1 $final_reduce
puts "DIRECT_ALL_V7_PLACEMENT: fourteen wrappers/controllers, four control banks, and four registered reducers assigned to physical SLRs"

# The full right-bank IBERT uses one uniform receiver configuration across
# X1Y4--X1Y59.  Apply the complete set of non-metadata primitive differences
# already required by the passing v6/q233 endpoint, now to all 56 managed
# direct channels.  The independent routed audit compares every primitive
# property against the golden checkpoint, not only this known set.
set direct_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE && NAME =~ *g_all_direct*}]
if {[llength $direct_channels] != 56} {
  error "Expected 56 managed direct GTYE4_CHANNEL primitives, got [llength $direct_channels]"
}
foreach channel $direct_channels {
  set_property -dict [list \
    ADAPT_CFG1 16'hFB1C RXCDR_CFG3 16'h0010 RXDFE_GC_CFG2 16'hFFE0 \
    RX_DEGEN_CTRL 3'b111 RX_DFE_AGC_CFG1 4 \
    RX_SUM_DEGEN_AVTT_OVERITE 1 RX_SUM_VCMTUNE 4'b1001 \
    PCI3_AUTO_REALIGN FRST_SMPL PCIE_PLL_SEL_MODE_GEN4 2'h0 \
    RX_PROGDIV_CFG 20.0 RX_PROGDIV_RATE 16'h0000 \
    RX_WIDEMODE_CDR_GEN3 2'b01 RXCDR_CFG3_GEN2 6'h10 \
    RXCDR_CFG3_GEN3 16'h0010 RXCDR_CFG3_GEN4 16'h0010] $channel
}
puts "DIRECT_ALL_V7_GOLDEN_RX: applied uniform full-IBERT receiver settings to 56 primitives"
