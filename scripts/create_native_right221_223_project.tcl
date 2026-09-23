# Create only the isolated q221-223 native Wizard project and generated IP.
#
# This is deliberately not a build: it creates no block design, does not add a
# top-level target, and never launches synthesis/implementation.  Its sole
# purpose is to expose the Wizard's generated shared-refclk/common structure
# for comparison against the Phase-0 routed IBERT baseline.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir native_right221_223_config.tcl]
source [file join $script_dir create_native_right221_223_ip.tcl]

set proof_project_dir [file join $repo_dir build $native_proof_name]
if {[file exists $proof_project_dir]} {
  # A failed IP-generation-only invocation may leave this project with the IP
  # customized but targets not yet generated. Resume only that exact project;
  # never overwrite an unrelated or versioned implementation project.
  set proof_project [file join $proof_project_dir ${native_proof_name}.xpr]
  if {![file exists $proof_project]} {
    error "Existing native proof directory lacks its expected project: $proof_project"
  }
  open_project $proof_project
  set existing_ips [get_ips -quiet native_right221_223_gt]
  if {[llength $existing_ips] != 1} {
    error "Existing native proof project does not contain exactly one native Wizard IP"
  }
  set native_gt [lindex $existing_ips 0]
} 
if {![info exists native_gt]} {
  create_project $native_proof_name $proof_project_dir -part xcvu13p-flga2577-2-e
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
  set native_gt [create_native_right221_223_ip]
}
if {[get_property IS_LOCKED $native_gt]} {
  error "Native q221-223 Wizard IP is locked"
}
generate_target all $native_gt
# The generic Wizard wrapper ties dedicated north/south refclk inputs low.
# Derive a separately named wrapper which retains its generated control logic
# but connects q221/q222/q223 to the baseline south/local/north topology.
source [file join $script_dir derive_native_right221_223_topology_wrapper.tcl]
report_property -all -file [file join $proof_project_dir native_right221_223_ip_properties.rpt] $native_gt
report_ip_status -file [file join $proof_project_dir ip_status.rpt]

set manifest [open [file join $proof_project_dir generated_ip_files.txt] w]
foreach file [lsort [get_files -all -quiet *native_right221_223_gt*]] {
  puts $manifest [get_property NAME $file]
}
# Not an IP-managed file: future proof projects must add this derived wrapper
# explicitly after adding the generated Wizard IP and its generated HDL.
puts $manifest $derived
close $manifest
puts "Created native q221-223 IP-generation-only project: $proof_project_dir"
puts "Next: inspect generated_ip_files.txt and compare generated refclk/common topology to the Phase-0 baseline."
