# Synthesis-only, target-local hierarchy contract for the reviewed all-links
# v1 timing experiment.  Do not attach this file to historical targets.
set all_links_v1_prbs_controllers [get_cells -hier -quiet -filter {
  REF_NAME =~ gt_prbs_test_controller*}]
set_property KEEP_HIERARCHY yes $all_links_v1_prbs_controllers
