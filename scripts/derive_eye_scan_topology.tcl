# Separate copies of the proven v3 topology; generated/vendor originals are
# immutable. The only changes are module rename and EYESCANRESET exposure.
set repo [file dirname [file dirname [file normalize [info script]]]]
set source_root [file join $repo build all_links_v3_topology_wrappers]
set outdir [file join $repo build eye_scan_v1_topology_wrappers]
if {[file exists $outdir]} {error "Refusing existing eye topology outputs $outdir"}
set expected {}
foreach {prefix first last} {all_links_v1 121 134 direct_all_v7 221 234} {
  for {set q $first} {$q <= $last} {incr q} {
    lappend expected [file join $source_root ${prefix}_q${q}_gt_v3_topology.v]
  }
}
set actual [glob -nocomplain [file join $source_root *_v3_topology.v]]
if {[lsort $expected] ne [lsort $actual]} {error "Expected exact 28 v3 topology inputs"}
set input_hashes [exec sha256sum {*}$expected]
set outputs {}
foreach src $expected {
  set f [open $src r]; set original [read $f]; close $f
  set oldname [file rootname [file tail $src]]
  set newname [string map {_v3_topology _eye_v1_topology} $oldname]
  set oldheader "module $oldname ("
  set newheader "module $newname (\n  eyescanreset_in,"
  set oldtie {.eyescanreset_in(4'H0)}
  set newtie {.eyescanreset_in(eyescanreset_in)}
  foreach anchor [list $oldheader $oldtie] {
    if {[llength [split [string map [list $anchor \u0001] $original] \u0001]] != 2} {
      error "Eye wrapper transform anchor not unique: $src $anchor"
    }
  }
  set text [string map [list $oldheader $newheader $oldtie $newtie] $original]
  set declaration {input wire [3:0] eyescanreset_in;}
  set pos [string first {input wire} $text]
  if {$pos < 0} {error "No port declaration in $src"}
  set text "[string range $text 0 [expr {$pos-1}]]$declaration\n[string range $text $pos end]"
  set restored [string map [list "$declaration\n" {} $newheader $oldheader $newtie $oldtie] $text]
  if {$restored ne $original} {error "Non-enumerated eye wrapper difference: $src"}
  lappend outputs $newname $text
}
# Validate the entire transform before writing anything.
if {[exec sha256sum {*}$expected] ne $input_hashes} {error "Topology inputs changed"}
file mkdir $outdir
foreach {name text} $outputs {
  set f [open [file join $outdir ${name}.v] {WRONLY CREAT EXCL}]
  puts -nonewline $f $text; close $f
  puts "EYE_WRAPPER $name exact_inverse_transform=PASS"
}
set f [open [file join $outdir SOURCE_SHA256SUMS] {WRONLY CREAT EXCL}]
puts $f $input_hashes; close $f
set files [lsort [glob [file join $outdir *.v]]]
set f [open [file join $outdir SHA256SUMS] {WRONLY CREAT EXCL}]
puts $f [exec sha256sum {*}$files]; close $f
# Syntax-check every derived outer wrapper without altering existing projects.
set compile_dir [file join $outdir syntax]
file mkdir $compile_dir
cd $compile_dir
puts [exec xvlog {*}$files]
if {[exec sha256sum {*}$expected] ne $input_hashes} {error "Baseline topology changed"}
puts "PASS: derived and syntax-checked 28 independent eye topology wrappers"
