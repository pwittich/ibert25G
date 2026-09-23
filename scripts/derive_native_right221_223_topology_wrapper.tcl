# Derive an integration wrapper from the generated q221-223 Wizard wrapper.
#
# Vivado's generic multi-quad wrapper exposes only three local COMMON refclks
# and ties all north/south dedicated-refclk ports low.  The generated lower
# `*_gtwizard_top` does expose those ports.  This script copies the generated
# outer wrapper to a separately named, build-local derived wrapper and makes
# only the six required connections from the q222 local input:
#   COMMON: q221 south, q222 local, q223 north
#   CHANNEL: q221 south, q222 local, q223 north
#
# The generated IP remains untouched.  The derived file is a reproducible
# build product, not a hand-maintained replacement for Vivado-owned sources.
# It must be used only with an IBUFDS_GTE4 output located at q222 connected to
# gtrefclk00_in[1].  Bits [0] and [2] are intentionally ignored.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set ip_dir [file join $repo_dir build gt_native_right221_223 \
  gt_native_right221_223.gen sources_1 ip native_right221_223_gt synth]
set source [file join $ip_dir native_right221_223_gt.v]
set derived [file join $ip_dir native_right221_223_gt_topology.v]
if {![file exists $source]} {
  error "Generate the native q221-223 Wizard IP before deriving its topology wrapper: $source"
}

set in [open $source r]
set text [read $in]
close $in

set substitutions [list \
  {module native_right221_223_gt (} {module native_right221_223_gt_topology (} \
  {.gtnorthrefclk00_in(3'H0)} {.gtnorthrefclk00_in({gtrefclk00_in[1], 2'b00})} \
  {.gtrefclk00_in(gtrefclk00_in)} {.gtrefclk00_in({1'b0, gtrefclk00_in[1], 1'b0})} \
  {.gtsouthrefclk00_in(3'H0)} {.gtsouthrefclk00_in({2'b00, gtrefclk00_in[1]})} \
  {.gtnorthrefclk0_in(12'H000)} {.gtnorthrefclk0_in({{4{gtrefclk00_in[1]}}, 8'b0})} \
  {.gtrefclk0_in(12'H000)} {.gtrefclk0_in({4'b0, {4{gtrefclk00_in[1]}}, 4'b0})} \
  {.gtsouthrefclk0_in(12'H000)} {.gtsouthrefclk0_in({8'b0, {4{gtrefclk00_in[1]}}})}]
foreach {from to} $substitutions {
  set count [regexp -all -- [regsub -all {([][(){}.^$*+?|\\])} $from {\\\1}] $text]
  if {$count != 1} {
    error "Expected one generated-wrapper occurrence of '$from', found $count"
  }
  set text [string map [list $from $to] $text]
}

# A topology wrapper must be distinguishable and must not retain any of the
# generic all-zero dedicated-refclk tie-offs.
foreach forbidden {\
  {.gtnorthrefclk00_in(3'H0)} {.gtsouthrefclk00_in(3'H0)} \
  {.gtnorthrefclk0_in(12'H000)} {.gtsouthrefclk0_in(12'H000)}} {
  if {[string first $forbidden $text] >= 0} {
    error "Derived wrapper still contains forbidden generic tie-off: $forbidden"
  }
}
set changed 1
if {[file exists $derived]} {
  set existing [open $derived r]
  set existing_text [read $existing]
  close $existing
  if {$existing_text eq $text} { set changed 0 }
}
if {$changed} {
  set out [open $derived w]
  puts -nonewline $out $text
  close $out
  puts "Wrote topology-preserving q221-223 derived wrapper: $derived"
} else {
  puts "Topology-preserving q221-223 derived wrapper is current: $derived"
}
