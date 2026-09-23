# Reproducibly generate separate functional FireFly-1 Wizard cores.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_native_left121_123_functional_ip_v1]
if {[file exists $project_dir]} { file delete -force $project_dir }
create_project gt_native_left121_123_functional_ip $project_dir -part xcvu13p-flga2577-2-e -force
source [file join $script_dir create_native_left121_123_functional_ip.tcl]
create_native_left121_123_functional_ip
generate_target all [get_ips]
foreach ip [get_ips] {
  if {[llength [get_property CONFIG.CHANNEL_ENABLE $ip]] != 4} {
    error "$ip did not retain four channels"
  }
}
puts "Created functional FireFly-1 q121/q122/q123 Wizard cores"
