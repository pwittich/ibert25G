# Read-only infrastructure preflight.  Use the verified loader because the
# Cornell lmutil binary names a legacy interpreter that is not installed.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set loader /lib64/ld-linux-x86-64.so.2
set lmutil /nfs/opt/Xilinx/Vivado/2023.2/bin/unwrapped/lnx64.o/lmutil
set server 2100@lnxlm.classe.cornell.edu
set output [exec $loader $lmutil lmstat -a -c $server]
set report [file join $repo_dir build all_links_v1_reports slr_bank_closeout license_status.rpt]
set out [open $report w]
puts $out $output
close $out
if {![regexp {license server UP} $output]} {error "FlexNet server did not report UP"}
puts "PASS: FlexNet license server reachable and UP through approved Vivado helper environment"
