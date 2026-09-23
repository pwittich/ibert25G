# Derive build-local outer-quad wrappers that select the physical center
# quad's REFCLK0 through the dedicated south/north ports.  Generated Wizard
# sources remain untouched and can always be regenerated from XCI.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set root [file join $repo_dir build direct_all_v7_ip direct_all_v7_ip.gen sources_1 ip]
set outdir [file join $repo_dir build direct_all_v7_topology_wrappers]
file mkdir $outdir
proc exact_count {text needle} {
  set count 0
  set start 0
  while {1} {
    set pos [string first $needle $text $start]
    if {$pos < 0} {return $count}
    incr count
    set start [expr {$pos + [string length $needle]}]
  }
}
foreach {quad route} {
  221 south 222 local 223 north 224 local 225 south 226 local 227 north
  228 south 229 local 230 north 231 local 232 south 233 local 234 north
} {
  set name direct_all_v7_q${quad}_gt
  set src [file join $root $name synth ${name}.v]
  set dst [file join $outdir ${name}_topology.v]
  if {![file isfile $src]} {error "Missing generated Wizard wrapper $src"}
  set f [open $src r]; set original [read $f]; close $f
  if {[string first "module ${name} (" $original] < 0} {error "Unexpected module header in $src"}
  set t [string map [list "module ${name} (" "module ${name}_topology ("] $original]
  if {$route eq "south"} {
    set maps [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtsouthrefclk00_in(1'H0)} {.gtsouthrefclk00_in(gtrefclk00_in[0])} \
      {.gtsouthrefclk0_in(4'H0)} {.gtsouthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H3)}]
  } elseif {$route eq "north"} {
    set maps [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtnorthrefclk00_in(1'H0)} {.gtnorthrefclk00_in(gtrefclk00_in[0])} \
      {.gtnorthrefclk0_in(4'H0)} {.gtnorthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H5)}]
  } else {set maps {}}
  foreach {old new} $maps {
    if {[exact_count $t $old] != 1} {
      error "Expected one '$old' in $src"
    }
  }
  set t [string map $maps $t]
  # Prove the clone differs only by the module rename plus the explicitly
  # enumerated selector substitutions above.  For local wrappers this reduces
  # to byte equivalence after undoing the module rename.
  set restored $t
  foreach {old new} $maps {set restored [string map [list $new $old] $restored]}
  set restored [string map [list "module ${name}_topology (" "module ${name} ("] $restored]
  if {$restored ne $original} {error "q$quad clone has a non-enumerated difference"}
  set o [open $dst w]; puts -nonewline $o $t; close $o
  puts "DIRECT_ALL_V7_REFCLK_WRAPPER q$quad route=$route exact_transform=PASS file=$dst"
}
puts "PASS: derived fourteen build-local topology wrappers; eight use dedicated outer routes"
