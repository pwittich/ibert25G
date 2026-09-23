# Build-local FireFly-1 topology wrappers.  Generated Wizard files are never
# edited: q121 uses the dedicated south route from q122, q122 local REFCLK0,
# and q123 the dedicated north route.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set root [file join $repo_dir build gt_native_left121_123_threecore_ip_v1 \
  gt_native_left121_123_threecore_ip.gen sources_1 ip]
foreach {quad route} {121 south 122 local 123 north} {
  set name native_left${quad}_gt
  set src [file join $root $name synth ${name}.v]
  set dst [file join $root $name synth ${name}_topology.v]
  set f [open $src r]; set t [read $f]; close $f
  set t [string map [list "module ${name} (" "module ${name}_topology ("] $t]
  set qpll_port "  qpll0lock_out,\n  qpll0outclk_out,"
  set qpll_decl [join [list {output wire [0 : 0] qpll0lock_out;} \
    {output wire [0 : 0] qpll0outclk_out;}] "\n"]
  set t [string map [list \
    {  qpll0outclk_out,} $qpll_port \
    {output wire [0 : 0] qpll0outclk_out;} $qpll_decl \
    {.qpll0lock_out(),} {.qpll0lock_out(qpll0lock_out),}] $t]
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
  puts "Derived FireFly-1 $route wrapper: $dst"
}
