# Derive three build-local wrappers; generated IP remains untouched.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set root [file join $repo_dir build gt_native_right221_223_threecore_ip_v3 gt_native_right221_223_threecore_ip.gen sources_1 ip]
foreach {quad route} {221 south 222 local 223 north} {
  set name native_right${quad}_gt
  set src [file join $root $name synth ${name}.v]
  set dst [file join $root $name synth ${name}_topology.v]
  set f [open $src r]; set t [read $f]; close $f
  set t [string map [list "module ${name} (" "module ${name}_topology ("] $t]
  # The Wizard's public wrapper discards QPLL0LOCK even though its generated
  # gtwizard_top instance produces it.  Expose that one status bit only on
  # this derived, build-local wrapper so the real quad supervisor can qualify
  # the live lock rather than a substitute signal.
  set qpll_port "  qpll0lock_out,\n  qpll0outclk_out,"
  set qpll_decl [join [list {output wire [0 : 0] qpll0lock_out;} \
    {output wire [0 : 0] qpll0outclk_out;}] "\n"]
  set t [string map [list \
    {  qpll0outclk_out,} $qpll_port \
    {output wire [0 : 0] qpll0outclk_out;} $qpll_decl \
    {.qpll0lock_out(),} {.qpll0lock_out(qpll0lock_out),}] $t]
  if {$route eq "south"} {
    # A four-channel Wizard emits one COMMON refclk input and four channel
    # refclk inputs (not the 3/12-wide ports of the earlier 12-channel
    # experiment).  Feed both from q222's physical REFCLK0 through the
    # dedicated south route; do not leave a hidden local source selected.
    set t [string map [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtsouthrefclk00_in(1'H0)} {.gtsouthrefclk00_in(gtrefclk00_in[0])} \
      {.gtsouthrefclk0_in(4'H0)} {.gtsouthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H3)}] $t]
  } elseif {$route eq "north"} {
    # q223 receives the same q222 source over its dedicated north route.
    set t [string map [list \
      {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in(1'H0)} \
      {.gtnorthrefclk00_in(1'H0)} {.gtnorthrefclk00_in(gtrefclk00_in[0])} \
      {.gtnorthrefclk0_in(4'H0)} {.gtnorthrefclk0_in({4{gtrefclk00_in[0]}})} \
      {.qpll0refclksel_in(3'H1)} {.qpll0refclksel_in(3'H5)}] $t]
  }
  set o [open $dst w]; puts -nonewline $o $t; close $o
  puts "Derived $route wrapper: $dst"
}
