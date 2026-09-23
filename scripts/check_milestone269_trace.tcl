# Fail before implementation if a top-level parameter truncates mode 2 or
# optimizes the recorder away. Check address/count width in the real netlist.
foreach pattern {
  {.*g_trace\.trace/next_index_reg\[7\]}
  {.*g_trace\.trace/count_reg\[8\]}
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] != 1} { error "Missing 256-entry trace structure: $pattern" }
}
puts "V269 256-entry diagnostic trace netlist verified"
