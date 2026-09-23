# Lightweight parser gate. This intentionally does not synthesize or build a
# bitstream; generated topology modules are permitted to remain unresolved.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set work [file join $repo_dir build all_links_v1_syntax]
file delete -force $work
file mkdir $work
cd $work
set sources {}
foreach name {
  direct_quad_v6_refclk_buffers direct_all_v7_quad_aggregate
  all_links_v1_quad_aggregate all_links_v1_slr_bank managed_direct_quad_v6_wrapper
  managed_all_links_left_quad_wrapper gt_test_direct_quad_v6_core
  gt_test_all_links_v1_top
} {lappend sources [file join $repo_dir src ${name}.sv]}
puts [exec xvlog -sv {*}$sources]
set core_file [open [file join $repo_dir src gt_test_direct_quad_v6_core.sv] r]
set core [read $core_file]; close $core_file
foreach required {
  {112'hffffffffffffffffffffffffffff}
  {`ALL_LINKS_BANK(g_bank_slr0, 0, 0, 3)}
  {`ALL_LINKS_BANK(g_bank_slr1, 1, 3, 4)}
  {`ALL_LINKS_BANK(g_bank_slr2, 2, 7, 4)}
  {`ALL_LINKS_BANK(g_bank_slr3, 3, 11, 3)}
  {reverse12(p_ff3_recv)}
} {
  if {[string first $required $core] < 0} {error "Missing all-links contract: $required"}
}
if {[regexp {u_ibert_(left|right)|axi_c2c} $core]} {
  error "Forbidden IBERT/C2C instance leaked into all-links core"
}
puts "PASS: all-links v1 RTL parses; full mask, four 6/8/8/6 SLR banks, reversed FF3, no IBERT/C2C"
