set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v3_xpm_repro_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/sim/tb_all_links_v3_xpm_repro.sv $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
exec xelab tb_all_links_v3_xpm_repro glbl -s xpm_repro -mt off -L xpm
set output [exec xsim xpm_repro -runall]
puts $output
if {![string match {*PASS: independent procedural*} $output] || [regexp {Fatal:} $output]} {
  error "Independent XPM monitor failed"
}
