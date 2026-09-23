proc direct_v6_strip_inherited_elf {bd_path} {
  set stream [open $bd_path r]
  set text [read $stream]
  close $stream
  set marker [string first "firmware_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.elf" $text]
  if {$marker < 0} {return 0}
  set start [string last "      \"file\": \{" $text $marker]
  set finish [string first "\n      \}," $text $marker]
  if {$start < 0 || $finish < 0} {error "Cannot delimit inherited ELF association in $bd_path"}
  set finish [expr {$finish + [string length "\n      \},"]}]
  set text [string replace $text $start $finish ""]
  set stream [open $bd_path w]
  puts -nonewline $stream $text
  close $stream
  return 1
}

proc direct_v6_assert_single_bd_elf {bd_path endpoint_name} {
  set stream [open $bd_path r]
  set text [read $stream]
  close $stream
  if {[string first "firmware_firefly1_loopback_v5" $text] >= 0} {error "Stale v5 ELF remains in $bd_path"}
  if {[regexp -all {"type": "ELF"} $text] != 1} {error "Expected exactly one ELF association in $bd_path"}
  if {[string first "firmware_direct_quad_v6_${endpoint_name}/gt_test_direct_quad_v6_${endpoint_name}.elf" $text] < 0} {
    error "Endpoint v6 ELF association missing in $bd_path"
  }
}

proc direct_v7_retarget_inherited_elf {bd_path} {
  set stream [open $bd_path r]
  set text [read $stream]
  close $stream
  set old "firmware_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.elf"
  set new "firmware_direct_all_v7/gt_test_direct_all_v7.elf"
  if {[regexp -all $old $text] != 1 || [regexp -all {"type": "ELF"} $text] != 1} {
    error "Expected exactly one inherited v5 ELF association in $bd_path"
  }
  set text [string map [list $old $new] $text]
  if {[regexp -all $new $text] != 1 || [string first $old $text] >= 0} {
    error "V7 ELF association retarget failed in $bd_path"
  }
  set stream [open $bd_path w]
  puts -nonewline $stream $text
  close $stream
}

proc direct_v7_assert_single_bd_elf {bd_path} {
  set stream [open $bd_path r]
  set text [read $stream]
  close $stream
  if {[regexp -all {"type": "ELF"} $text] != 1} {error "Expected exactly one ELF association in $bd_path"}
  if {[regexp -all {firmware_direct_all_v7/gt_test_direct_all_v7.elf} $text] != 1} {
    error "Exact v7 ELF association missing in $bd_path"
  }
  if {[string first "firmware_firefly1_loopback_v5" $text] >= 0} {error "Stale v5 ELF remains in $bd_path"}
}
