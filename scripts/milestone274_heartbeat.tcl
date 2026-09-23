# Fixed v274 heartbeat-monitor suppression. Run on lnx4189; never halt/reset.
set evidence /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/build/v274-run2-heartbeat-xsdb.log
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
if {[read32 0x44a00004] != 0x00020118 ||
    [read32 0x44a00010] != 0 || [read32 0x44a00018] != 1 ||
    [read32 0x44a000a0] != 1 || [read32 0x44a00060] != 0} {
  error "Unexpected v274 pre-arm identity/state/run/sequence/toggle"
}
note "ARMED v274; awaiting sequence 2 RUN, prior completed run ID 1"
set deadline [expr {[clock milliseconds] + 120000}]
while {1} {
  set sequence [read32 0x44a000a0]
  set state [read32 0x44a00010]
  if {$sequence > 2 || ($state & 0x10000)} {error "Unexpected sequence/platform fault; no stimulus"}
  if {$sequence == 2 && $state == 2} {break}
  if {[clock milliseconds] >= $deadline} {error "No matching RUN before deadline; no stimulus"}
  after 100
}
after 250
if {[read32 0x44a00004] != 0x00020118 ||
    [read32 0x44a000a0] != 2 || [read32 0x44a00010] != 2 ||
    [read32 0x44a00018] != 1 || [read32 0x44a0002c] != 0xf000 ||
    [read32 0x44a00060] != 0} {
  error "Pre-stimulus identity/state/descriptor/toggle mismatch; no stimulus"
}
set suppression_asserted 0
set operation_status [catch {
  note "WRITE_BEGIN heartbeat suppression via mwr 0x44a00060 0x00008000"
  mwr 0x44a00060 0x00008000
  set suppression_asserted 1
  note "WRITE_END heartbeat suppression asserted"
  if {[read32 0x44a00060] != 0x00008000} {
    error "Suppression toggle readback failed"
  }
  set fault_deadline [expr {[clock milliseconds] + 2000}]
  while {1} {
    set state [read32 0x44a00010]
    if {$state == 0x00010000} {break}
    if {[read32 0x44a000a0] != 2} {error "Sequence changed while awaiting fault"}
    if {[clock milliseconds] >= $fault_deadline} {error "Heartbeat fault timeout"}
    after 10
  }
  note "FAULT_OBSERVED"
} operation_error operation_options]

# Once suppression is written, restoration is unconditional—even if fault
# observation or readback validation fails. This is the only second write.
set restore_status 0
if {$suppression_asserted} {
  note "RESTORE_BEGIN heartbeat monitor input"
  set restore_status [catch {
    mwr 0x44a00060 0x00008000
    if {[read32 0x44a00060] != 0} {
      error "Heartbeat restoration toggle readback failed"
    }
  } restore_error restore_options]
  if {!$restore_status} {
    note "HEARTBEAT_RESTORED; exactly two writes, no halt/reset/programming"
  }
}
close $logfd
if {$restore_status} {
  return -options $restore_options $restore_error
}
if {$operation_status} {
  return -options $operation_options $operation_error
}
