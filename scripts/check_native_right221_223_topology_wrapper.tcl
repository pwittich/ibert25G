# Textual structural gate for the derived q221-223 wrapper.  This validates
# the static dedicated-route mapping before any future elaboration/build.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set wrapper [file join $repo_dir build gt_native_right221_223 \
  gt_native_right221_223.gen sources_1 ip native_right221_223_gt synth \
  native_right221_223_gt_topology.v]
if {![file exists $wrapper]} {
  error "Missing derived q221-223 topology wrapper: $wrapper"
}
set fh [open $wrapper r]
set text [read $fh]
close $fh
foreach required {
  {module native_right221_223_gt_topology (}
  {.gtnorthrefclk00_in({gtrefclk00_in[1], 2'b00})}
  {.gtrefclk00_in({1'b0, gtrefclk00_in[1], 1'b0})}
  {.gtsouthrefclk00_in({2'b00, gtrefclk00_in[1]})}
  {.gtnorthrefclk0_in({{4{gtrefclk00_in[1]}}, 8'b0})}
  {.gtrefclk0_in({4'b0, {4{gtrefclk00_in[1]}}, 4'b0})}
  {.gtsouthrefclk0_in({8'b0, {4{gtrefclk00_in[1]}}})}
} {
  if {[string first $required $text] < 0} {
    error "Missing q221-223 dedicated-refclk mapping: $required"
  }
}
foreach forbidden {
  {.gtnorthrefclk00_in(3'H0)} {.gtsouthrefclk00_in(3'H0)}
  {.gtnorthrefclk0_in(12'H000)} {.gtsouthrefclk0_in(12'H000)}
} {
  if {[string first $forbidden $text] >= 0} {
    error "Found generic dedicated-refclk tie-off: $forbidden"
  }
}
puts "Native q221-223 topology wrapper preserves q221=south, q222=local, q223=north"
