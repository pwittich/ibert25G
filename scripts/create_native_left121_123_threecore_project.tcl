# IP-only project for the isolated FireFly-1 three-quad feasibility proof.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_native_left121_123_threecore_ip_v1]
set project_file [file join $project_dir gt_native_left121_123_threecore_ip.xpr]
if {[file exists $project_dir]} {
  if {![file exists $project_file]} { error "Refusing incomplete foreign directory: $project_dir" }
  open_project $project_file
} else {
  create_project gt_native_left121_123_threecore_ip $project_dir -part xcvu13p-flga2577-2-e
}
source [file join $script_dir create_native_left121_123_threecore_ip.tcl]
if {[llength [get_ips -quiet native_left121_gt]] == 0} {
  create_native_left121_123_threecore_ip
}
generate_target all [get_ips]
foreach ip [get_ips] {
  set channels [get_property CONFIG.CHANNEL_ENABLE $ip]
  if {[llength $channels] != 4} { error "$ip did not retain four channels: $channels" }
}
puts "Created isolated three-core q121-q123 Wizard experiment"
