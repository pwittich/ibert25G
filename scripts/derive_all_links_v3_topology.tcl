set repo_dir [file dirname [file dirname [file normalize [info script]]]]
set outdir [file join $repo_dir build all_links_v3_topology_wrappers]
if {[file exists $outdir]} {error "Refusing existing v3 topology outputs"}
file mkdir $outdir
foreach {subdir globpattern} {
  all_links_v1_left_topology_wrappers all_links_v1_q*_gt_topology.v
  direct_all_v7_topology_wrappers direct_all_v7_q*_gt_topology.v
} {
  set sources [lsort [glob [file join $repo_dir build $subdir $globpattern]]]
  if {[llength $sources] != 14} {error "Expected 14 wrappers in $subdir"}
  foreach src $sources {
    set oldname [file rootname [file tail $src]]
    set newname [string map {_topology _v3_topology} $oldname]
    set f [open $src r]; set original [read $f]; close $f
    foreach needle [list "module $oldname (" {.txelecidle_in(4'H0)}] {
      if {[llength [split [string map [list $needle \u0001] $original] \u0001]] != 2} {
        error "Wrapper transform anchor is not unique: $src $needle"
      }
    }
    set header "module $newname (\n  txelecidle_in,"
    set text [string map [list "module $oldname (" $header \
      {.txelecidle_in(4'H0)} {.txelecidle_in(txelecidle_in)}] $original]
    set declaration {input wire [3:0] txelecidle_in;}
    set pos [string first {input wire} $text]
    if {$pos < 0} {error "No port declarations in $src"}
    set text "[string range $text 0 [expr {$pos-1}]]$declaration\n[string range $text $pos end]"
    if {[string first $declaration $text] < 0} {error "Missing inserted declaration"}
    set restored [string map [list "$declaration\n" {} $header "module $oldname (" \
      {.txelecidle_in(txelecidle_in)} {.txelecidle_in(4'H0)}] $text]
    if {$restored ne $original} {error "Non-enumerated v3 wrapper difference in $src"}
    set f [open [file join $outdir $newname.v] {WRONLY CREAT EXCL}]
    puts -nonewline $f $text; close $f
    puts "V3_WRAPPER $newname exact_transform=PASS"
  }
}
