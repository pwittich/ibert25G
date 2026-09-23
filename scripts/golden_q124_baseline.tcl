# One external PRBS31 comparison, no optical fault stimulus or automatic retry.
open_hw_manager
connect_hw_server -url TCP:lnx4189:3121
set chains [get_hw_targets]
if {[llength $chains] != 1} {error "Expected one JTAG chain"}
open_hw_target [lindex $chains 0]
set devices [get_hw_devices]
if {[llength $devices] != 2} {error "Expected two FPGAs"}
set f1 [lindex $devices 0]
current_hw_device $f1
refresh_hw_device -update_hw_probes false $f1
set groups [get_hw_sio_gtgroups -quiet -of_objects $f1 -filter {NAME =~ *Quad_124}]
if {[llength $groups] != 1} {error "Expected one F1 Quad_124"}
set gts [get_hw_sio_gts -quiet -of_objects $groups]
if {[llength $gts] != 4} {error "Expected four Quad_124 lanes"}
foreach gt $gts {puts "TARGET $gt [get_property DISPLAY_NAME $gt]"}
set links {}
foreach gt $gts {
    lappend links [create_hw_sio_link -description "golden_compare_[get_property DISPLAY_NAME $gt]" \
        [get_hw_sio_rxs -of_objects $gt] [get_hw_sio_txs -of_objects $gt]]
}
set_property TX_PATTERN {PRBS 31-bit} $links
set_property RX_PATTERN {PRBS 31-bit} $links
set_property LOOPBACK None $links
commit_hw_sio $links
after 500
foreach {reset wait_ms} {LOGIC.TX_RESET_ALL 1000 LOGIC.RX_RESET_ALL 3000 LOGIC.MGT_ERRCNT_RESET_CTRL 0} {
    set_property $reset 1 $gts
    commit_hw_sio $gts
    after 100
    set_property $reset 0 $gts
    commit_hw_sio $gts
    after $wait_ms
}
puts "GOLDEN_BASELINE_STARTED [clock seconds]"
after 10000
refresh_hw_sio -properties {PORT.RXCDRLOCK PORT.RXELECIDLE PORT.RXRESETDONE PORT.TXRESETDONE LOGIC.RXUSRCLK2_FREQ_CNT LOGIC.ERRBIT_COUNT RX_RECEIVED_BIT_COUNT RX_BER} $gts
foreach gt $gts {
    puts "RESULT [get_property DISPLAY_NAME $gt]"
    foreach property {PORT.RXCDRLOCK PORT.RXELECIDLE PORT.RXRESETDONE PORT.TXRESETDONE LOGIC.RXUSRCLK2_FREQ_CNT LOGIC.ERRBIT_COUNT RX_RECEIVED_BIT_COUNT RX_BER} {
        puts "$property=[get_property $property $gt]"
    }
}
puts "GOLDEN_BASELINE_CAPTURED [clock seconds]"
close_hw_manager
