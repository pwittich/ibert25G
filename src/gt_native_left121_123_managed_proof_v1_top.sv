// Reuse the verified isolated three-supervisor harness while substituting
// only the three FireFly-1 native wrappers.  The harness port names remain
// generic proof names; its XDC binds the REFCLK input to lf_r0_ad/q122.
`define native_right221_gt_topology native_left121_gt_topology
`define native_right222_gt_topology native_left122_gt_topology
`define native_right223_gt_topology native_left123_gt_topology
`define gt_native_right221_223_managed_proof_v1_top gt_native_left121_123_managed_proof_v1_top
`include "gt_native_right221_223_managed_proof_v1_top.sv"
`undef gt_native_right221_223_managed_proof_v1_top
`undef native_right223_gt_topology
`undef native_right222_gt_topology
`undef native_right221_gt_topology
