# Syntax gate only; not controller simulation or elaboration of vendor IP.
set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build direct_quad_v6_syntax]
file mkdir $work
cd $work
set sources {}
foreach name {
  managed_direct_quad_v6_wrapper direct_quad_v6_refclk_buffers
  gt_test_direct_quad_v6_core gt_test_direct_quad_v6_f1_top gt_test_direct_quad_v6_f2_top
} {lappend sources [file join $repo src ${name}.sv]}
puts [exec xvlog -sv {*}$sources]
puts "PASS: direct v6 RTL syntax only; functional simulation remains required"
