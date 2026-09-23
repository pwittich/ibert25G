# Offline read-only comparison. Does not connect to hardware or modify DCPs.
set repo [file dirname [file dirname [file normalize [info script]]]]
proc static_port {cell port width} {
    set value 0
    for {set b 0} {$b < $width} {incr b} {
        set name [expr {$width == 1 ? $port : [format {%s[%d]} $port $b]}]
        set p [get_pins -quiet $cell/$name]
        if {[llength $p] != 1} {return UNKNOWN_PIN}
        set net [get_nets -quiet -of_objects $p]
        if {[llength $net] != 1} {return UNKNOWN_NET}
        set type [get_property TYPE $net]
        if {$type eq "POWER"} {set value [expr {$value | (1 << $b)}]} \
        elseif {$type ne "GROUND"} {return DYNAMIC}
    }
    return $value
}
foreach {label path} {
    golden build/vu13p_ibert_25g.runs/impl_1/top_routed.dcp
    v5 build/gt_test_firefly1_loopback_v5/gt_test_firefly1_loopback_v5_routed.dcp
} {
    set dcp [file join $repo $path]
    puts "CHECKPOINT $label [exec sha256sum $dcp]"
    open_checkpoint $dcp
    set count 0
    foreach c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}] {
        set loc [get_property LOC $c]
        if {![regexp {GTYE4_CHANNEL_X0Y([0-9]+)$} $loc -> y] || $y<4 || $y>15} {continue}
        incr count
        puts "CHANNEL $label $loc"
        foreach {p n} {TXDIFFCTRL 5 TXPRECURSOR 5 TXPOSTCURSOR 5 RXPOLARITY 1 TXPOLARITY 1 RXLPMEN 1} {
            puts "PORT $p [static_port $c $p $n]"
        }
        foreach p {ADAPT_CFG1 RXCDR_CFG3 RXDFE_GC_CFG2 RX_DEGEN_CTRL RX_DFE_AGC_CFG1 RX_SUM_DEGEN_AVTT_OVERITE RX_SUM_VCMTUNE RX_DATA_WIDTH TX_DATA_WIDTH RX_INT_DATAWIDTH TX_INT_DATAWIDTH} {
            puts "PROPERTY $p [get_property $p $c]"
        }
    }
    if {$count!=12} {error "expected12 FireFly1 channels in $label, got$count"}
    close_design
}
puts "PASS: offline golden/v5 FireFly1 configuration capture (not live GUI settings)"
