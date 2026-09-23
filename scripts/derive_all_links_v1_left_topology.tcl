# Clone only top-level generated Wizard wrappers so outer quads select the
# documented neighboring REFCLK0 dedicated route. Generated IP is read-only.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set root [file join $repo_dir build all_links_v1_left_ip \
  all_links_v1_left_ip.gen sources_1 ip]
set outdir [file join $repo_dir build all_links_v1_left_topology_wrappers]
if {[file exists $outdir]} {error "Refusing to overwrite $outdir"}
file mkdir $outdir
proc exact_count {text needle} {
  set count 0; set start 0
  while {1} {
    set pos [string first $needle $text $start]
    if {$pos < 0} {return $count}
    incr count; set start [expr {$pos + [string length $needle]}]
  }
}
foreach {quad route} {
  121 south 122 local 123 north 124 local 125 south 126 local 127 north
  128 south 129 local 130 north 131 local 132 south 133 local 134 north
} {
  set name all_links_v1_q${quad}_gt
  set src [file join $root $name synth ${name}.v]
  set dst [file join $outdir ${name}_topology.v]
  if {![file isfile $src]} {error "Missing $src"}
  set f [open $src r]; set original [read $f]; close $f
  if {[string first "module ${name} (" $original] < 0} {error "Unexpected module $src"}
  set text [string map [list "module ${name} (" "module ${name}_topology ("] $original]
  if {$route eq "south"} {
    set maps [list {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtsouthrefclk00_in(1'H0)} {.gtsouthrefclk00_in(gtrefclk00_in[0])} \
      {.gtsouthrefclk0_in(4'H0)} {.gtsouthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H3)}]
  } elseif {$route eq "north"} {
    set maps [list {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtnorthrefclk00_in(1'H0)} {.gtnorthrefclk00_in(gtrefclk00_in[0])} \
      {.gtnorthrefclk0_in(4'H0)} {.gtnorthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H5)}]
  } else {set maps {}}
  foreach {old new} $maps {
    if {[exact_count $text $old] != 1} {error "Expected one '$old' in $src"}
  }
  set text [string map $maps $text]
  set restored $text
  foreach {old new} $maps {set restored [string map [list $new $old] $restored]}
  set restored [string map [list "module ${name}_topology (" "module ${name} ("] $restored]
  if {$restored ne $original} {error "q$quad clone contains an unlisted change"}
  set o [open $dst w]; puts -nonewline $o $text; close $o
  puts "ALL_LINKS_V1_LEFT_REFCLK q$quad route=$route exact_transform=PASS"
}
puts "PASS: derived fourteen all-links v1 left topology wrappers"
