# Read-only enumeration of Apollo's fixed Xilinx Virtual Cable endpoint.
set endpoint TCP:apollo3010-1:2542
puts "JTAG_XVC_ENDPOINT_BEGIN $endpoint"
if {[catch {connect -xvc-url $endpoint} message]} {
    puts "JTAG_XVC_CONNECT_ERROR $message"
} else {
    after 2000
    set target_list [targets]
    puts "JTAG_XVC_TARGET_RETURN <$target_list>"
    targets
    disconnect
}
puts "JTAG_XVC_ENDPOINT_END $endpoint"
exit
