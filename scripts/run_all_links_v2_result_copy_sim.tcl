set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v2_result_copy_sim]
file delete -force $work
file mkdir $work
cd $work
exec xvlog -sv $repo/src/all_links_v2_result_copy_bank.sv \
  $repo/sim/tb_all_links_v2_result_copy_bank.sv
exec xelab tb_all_links_v2_result_copy_bank -s all_links_v2_result_copy -mt off
set output [exec xsim all_links_v2_result_copy -runall]
puts $output
if {![string match {*PASS: all 112 result-copy lanes*} $output]} {
  error "all-links v2 result-copy simulation failed"
}
