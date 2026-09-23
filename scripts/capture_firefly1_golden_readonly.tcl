# Fixed read-only XVC capture. NO program, reset, set_property,
# commit_hw_sio, or new link is permitted.
# Delta samples preserve existing counters rather than clearing their history.
# Run through board_golden_xvc.py: its private temporary bridge is independent
# of the user's GUI/server. The board transport is always the fixed Apollo XVC.
if {![string match lnx4189* [info hostname]]} {error "Run this capture on lnx4189 only"}
open_hw_manager
connect_hw_server -url TCP:127.0.0.1:43121
set xvc_ip [lindex [exec getent ahostsv4 apollo3010-1] 0]
if {![regexp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$} $xvc_ip]} {error "Apollo IPv4 lookup failed"}
puts "XVC_ENDPOINT apollo3010-1 $xvc_ip:2542"
open_hw_target -xvc_url $xvc_ip:2542
puts "XVC_TARGET [current_hw_target]"
set devices [get_hw_devices -quiet]
puts "DEVICE_ORDER $devices"
if {[llength $devices]!=2} {error "Expected exactly two FPGAs; refuse ambiguous chain"}
set channels {}
foreach device $devices {
    puts "DEVICE $device"
    refresh_hw_device -update_hw_probes false $device
    foreach p {NAME PART IDCODE DNA_STRING} {
        if {[lsearch -exact [list_property $device] $p]>=0} {
            puts "DEVICE_PROPERTY $p [get_property $p $device]"
        }
    }
    set found 0
    foreach group [get_hw_sio_gtgroups -quiet -of_objects $device] {
        if {![regexp {Quad_12[123]$} [get_property NAME $group]]} {continue}
        foreach gt [get_hw_sio_gts -quiet -of_objects $group] {
            lappend channels $gt; incr found
        }
    }
    if {$found!=12} {error "Expected12 q121-123 GTs on $device, got$found"}
}
proc sample {tag channels} {
    puts "SAMPLE_BEGIN $tag [clock milliseconds]"
    set objects {}
    foreach gt $channels {
        lappend objects $gt
        foreach endpoint [get_hw_sio_rxs -quiet -of_objects $gt] {lappend objects $endpoint}
        foreach endpoint [get_hw_sio_txs -quiet -of_objects $gt] {lappend objects $endpoint}
    }
    foreach gt $objects {
        set props {}
        foreach p [list_property $gt] {
            if {[regexp -nocase {PATTERN|LOOPBACK|DIFF|CURSOR|POLAR|LPM|COUNT|LOCK|RESETDONE|FREQ|BER|NAME} $p]} {lappend props $p}
        }
        refresh_hw_sio -properties $props $gt
        puts "GT $tag $gt [clock milliseconds]"
        foreach p $props {puts "PROPERTY $p [get_property $p $gt]"}
    }
    puts "SAMPLE_END $tag [clock milliseconds]"
}
sample before $channels
after 10000
sample after $channels
puts "READONLY_CAPTURE_COMPLETE (interpret deltas/configuration before claiming baseline)"
close_hw_manager
