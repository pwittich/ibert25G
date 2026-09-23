# Explicit read-only generated-HDL manifest for the eight derived outer-quad
# wrappers.  Source IP products are never edited; generic support modules are
# selected once from q221 to avoid duplicate definitions.
proc direct_all_v7_support_manifest {repo_dir} {
  set root [file join $repo_dir build direct_all_v7_ip direct_all_v7_ip.gen sources_1 ip]
  set files {}
  set q221 [file join $root direct_all_v7_q221_gt]
  foreach f [lsort [glob -nocomplain [file join $q221 hdl *.v]]] {lappend files $f}
  foreach f {
    gtwizard_ultrascale_v1_7_gtye4_channel.v
    gtwizard_ultrascale_v1_7_gtye4_common.v
  } {lappend files [file join $q221 synth $f]}
  foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
    set d [file join $root direct_all_v7_q${quad}_gt synth]
    foreach suffix {gtwizard_gtye4.v gtwizard_top.v gtye4_channel_wrapper.v gtye4_common_wrapper.v} {
      lappend files [file join $d direct_all_v7_q${quad}_gt_${suffix}]
    }
  }
  set modules {}
  foreach f $files {
    if {![file isfile $f]} {error "Missing generated support HDL $f"}
    set h [open $f r]; set text [read $h]; close $h
    foreach line [split $text "\n"] {
      if {[regexp {^\s*module\s+([A-Za-z0-9_]+)} $line -> module_name]} {
        if {[dict exists $modules $module_name]} {
          error "Duplicate generated module $module_name in [dict get $modules $module_name] and $f"
        }
        dict set modules $module_name $f
      }
    }
  }
  foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
    if {![dict exists $modules direct_all_v7_q${quad}_gt_gtwizard_top]} {
      error "Manifest misses q$quad gtwizard top"
    }
  }
  return $files
}

proc direct_all_v7_outer_xdc_manifest {repo_dir} {
  set root [file join $repo_dir build direct_all_v7_ip direct_all_v7_ip.gen sources_1 ip]
  set result {}
  foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
    set f [file join $root direct_all_v7_q${quad}_gt synth direct_all_v7_q${quad}_gt.xdc]
    if {![file isfile $f]} {error "Missing generated outer-quad XDC $f"}
    lappend result $quad $f
  }
  return $result
}
