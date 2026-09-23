# One-shot v273 non-trip control. Run on lnx4189; never halt or reset MicroBlaze.
set evidence /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/build/v273-run4-xsdb.log
set logfd [open $evidence {WRONLY CREAT EXCL}]
proc note {message} {
  global logfd
  set line "[clock milliseconds] $message"
  puts $line
  puts $logfd $line
  flush $logfd
  flush stdout
}
proc read32 {address} {
  set raw [mrd $address]
  if {![regexp {:\s+([0-9a-fA-F]{8})} $raw unused word]} {
    error "Unexpected mrd response: $raw"
  }
  scan $word %x value
  return $value
}
connect -url TCP:lnx4189:3121
note "TARGETS [targets]"
targets 3
if {[read32 0x44a00004] != 0x00020117 ||
    [read32 0x44a00010] != 0 || [read32 0x44a00018] != 3 ||
    [read32 0x44a000a0] != 3} {error "Unexpected pre-arm version/state/run/sequence"}
note "ARMED v273; awaiting sequence 4 RUN, prior completed run ID 3"
set deadline [expr {[clock milliseconds] + 120000}]
while {1} {
  set sequence [read32 0x44a000a0]
  set state [read32 0x44a00010]
  if {$sequence > 4 || ($state & 0x10000)} {error "Unexpected sequence/platform fault; no pulse"}
  if {$sequence == 4 && $state == 2} {break}
  if {[clock milliseconds] >= $deadline} {error "No matching RUN before deadline; no pulse"}
  after 100
}
after 250
if {[read32 0x44a00004] != 0x00020117 ||
    [read32 0x44a000a0] != 4 || [read32 0x44a00010] != 2 ||
    [read32 0x44a00018] != 3 || [read32 0x44a0002c] != 0xf000} {
  error "Pre-pulse identity/state/descriptor mismatch; no pulse"
}
set before [read32 0x44a00060]
note [format "PRE_PULSE sequence=4 state=2 completed_run_id=3 mask=0xf000 toggle=0x%08x" $before]
note "WRITE_BEGIN mwr 0x44a00060 0x1000 (exactly once)"
mwr 0x44a00060 0x1000
note "WRITE_END"
set after_toggle [read32 0x44a00060]
set state [read32 0x44a00010]
note [format "POST_PULSE toggle=0x%08x state=0x%08x" $after_toggle $state]
if {($before ^ $after_toggle) != 0x1000 || $state != 2} {
  error "Pulse readback/state validation failed; do not retry"
}
note "ONE_LANE12_PULSE_CONFIRMED; no other writes, halt, reset or programming"
close $logfd
