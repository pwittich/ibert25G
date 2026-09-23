# Build-local functional topology wrappers. The source Wizard files remain
# Vivado-owned; this only makes the q122 REFCLK0 reach q121/q123 through their
# dedicated common-to-common north/south paths.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set root [file join $repo_dir build gt_native_left121_123_functional_ip_v1 \
  gt_native_left121_123_functional_ip.gen sources_1 ip]
foreach {quad route} {121 south 122 local 123 north} {
  set name native_left${quad}_functional_gt
  set src [file join $root $name synth ${name}.v]
  set dst [file join $root $name synth ${name}_topology.v]
  if {![file exists $src]} { error "Missing generated functional Wizard: $src" }
  set f [open $src r]; set t [read $f]; close $f
  set t [string map [list "module ${name} (" "module ${name}_topology ("] $t]
  if {$route eq "south"} {
    set t [string map [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtsouthrefclk00_in(1'H0)} {.gtsouthrefclk00_in(gtrefclk00_in[0])} \
      {.gtsouthrefclk0_in(4'H0)} {.gtsouthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H3)}] $t]
  } elseif {$route eq "north"} {
    set t [string map [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtnorthrefclk00_in(1'H0)} {.gtnorthrefclk00_in(gtrefclk00_in[0])} \
      {.gtnorthrefclk0_in(4'H0)} {.gtnorthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H5)}] $t]
  }
  set o [open $dst w]; puts -nonewline $o $t; close $o
  puts "Derived functional FireFly-1 $route wrapper: $dst"
}
