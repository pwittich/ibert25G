if {$argc == 0 || [lindex $argv 0] in {-h --help}} {
  puts "usage: vivado -mode batch -source report-ip-health.tcl -tclargs PROJECT_XPR ?REPORT_DIR?"
  exit 0
}

set project_file [file normalize [lindex $argv 0]]
set report_dir [file join [pwd] ip-reports]
if {$argc > 1} { set report_dir [file normalize [lindex $argv 1]] }
if {![file exists $project_file]} { error "Project not found: $project_file" }
file mkdir $report_dir
open_project $project_file

set ips [get_ips -quiet]
if {[llength $ips] == 0} { error "No IP found in $project_file" }
report_ip_status -file [file join $report_dir ip_status.rpt]

set locked {}
set fh [open [file join $report_dir ip_inventory.tsv] w]
puts $fh "name\tvlnv\tlocked"
foreach ip $ips {
  set is_locked [get_property IS_LOCKED $ip]
  if {$is_locked} { lappend locked $ip }
  puts $fh "[get_property NAME $ip]\t[get_property IPDEF $ip]\t$is_locked"
}
close $fh

puts "Wrote IP reports to $report_dir"
if {[llength $locked]} { error "Locked IP cores: [join $locked {, }]" }
