# Explicit generated-HDL manifest. Generic Wizard support is selected once
# from q121; each quad contributes only its uniquely named wrappers.
proc all_links_v1_left_support_manifest {repo_dir} {
  set root [file join $repo_dir build all_links_v1_left_ip \
    all_links_v1_left_ip.gen sources_1 ip]
  set files {}
  set q121 [file join $root all_links_v1_q121_gt]
  foreach f [lsort [glob -nocomplain [file join $q121 hdl *.v]]] {lappend files $f}
  foreach f {gtwizard_ultrascale_v1_7_gtye4_channel.v
             gtwizard_ultrascale_v1_7_gtye4_common.v} {
    lappend files [file join $q121 synth $f]
  }
  foreach quad {121 122 123 124 125 126 127 128 129 130 131 132 133 134} {
    set d [file join $root all_links_v1_q${quad}_gt synth]
    foreach suffix {gtwizard_gtye4.v gtwizard_top.v
                    gtye4_channel_wrapper.v gtye4_common_wrapper.v} {
      lappend files [file join $d all_links_v1_q${quad}_gt_${suffix}]
    }
  }
  foreach f $files {if {![file isfile $f]} {error "Missing generated support $f"}}
  return $files
}

proc all_links_v1_left_xdc_manifest {repo_dir} {
  set root [file join $repo_dir build all_links_v1_left_ip \
    all_links_v1_left_ip.gen sources_1 ip]
  set result {}
  foreach quad {121 122 123 124 125 126 127 128 129 130 131 132 133 134} {
    set xdc [file join $root all_links_v1_q${quad}_gt synth \
      all_links_v1_q${quad}_gt.xdc]
    if {![file isfile $xdc]} {error "Missing generated outer XDC $xdc"}
    lappend result $quad $xdc
  }
  return $result
}
