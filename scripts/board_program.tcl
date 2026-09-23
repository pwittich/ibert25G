# Runs only on lnx4189. Fixed targets/artifacts; no arbitrary Tcl evaluation.
if {$argc != 1} {error "Expected exactly one image name"}
set root /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g
switch -- [lindex $argv 0] {
    v270 {
        set bitfile $root/build/gt_test_milestone270/gt_test_milestone270.runs/impl_1/gt_test_milestone270.bit
        set expected 72f3a2fa5b97f30cd503631fa16af03715a165a1865d7278fd5a249874bdefe4
        set elf $root/build/firmware270/gt_test_milestone270.elf
        if {[lindex [exec sha256sum $elf] 0] ne "0f91bee392bb1de414834cb03f6cd5f63a503cd8401b8365f599f81ac60677cf"} {error "ELF hash mismatch"}
    }
    v271 {
        set bitfile $root/build/gt_test_milestone271/gt_test_milestone271.runs/impl_1/gt_test_milestone271.bit
        set expected 54b4d2cebe0b09422a9713a534c3100b8d6371ef8aac022d00943417c1e76f83
        set elf $root/build/firmware271/gt_test_milestone271.elf
        if {[lindex [exec sha256sum $elf] 0] ne "3235e58340f1f7624831a47e2db0453ca757809d08c536f3f588c828c939bd96"} {error "ELF hash mismatch"}
    }
    v272 {
        set bitfile $root/build/gt_test_milestone272/gt_test_milestone272.runs/impl_1/gt_test_milestone272.bit
        set expected 7ca91032b55f3e71a97dd27678ab5b1bf9b00cbd0d105646cdcdc0666147215d
        set elf $root/build/firmware272/gt_test_milestone272.elf
        if {[lindex [exec sha256sum $elf] 0] ne "38187f08c33b02602623d7d25db136b70cfcac5611f9d7eeb1b786845daacf0c"} {error "ELF hash mismatch"}
    }
    v273 {
        set bitfile $root/build/gt_test_milestone273/gt_test_milestone273.runs/impl_1/gt_test_milestone273.bit
        set expected 84a2d4db34f8ac4437dbec6f89fb2931f76f663a1846ba5b1e7d2075b08cfedf
        set elf $root/build/firmware273/gt_test_milestone273.elf
        if {[lindex [exec sha256sum $elf] 0] ne "e32976fabe1e7834fc34c14db21829b25741386278663869bb544c4721beb62b"} {error "ELF hash mismatch"}
    }
    v274 {
        set bitfile $root/build/gt_test_milestone274/gt_test_milestone274.runs/impl_1/gt_test_milestone274.bit
        set expected 0dd18f901c69f43e51a80aeb5e9e0727b8842e9aa98f69565af3ee07f48ad80a
        set elf $root/build/firmware274/gt_test_milestone274.elf
        if {[lindex [exec sha256sum $elf] 0] ne "dc20fc8b37d19d393f031786df21313df5aee9dc82f21ef0c1102ee5e5b1d7b0"} {error "ELF hash mismatch"}
    }
    v275 {
        set bitfile $root/build/gt_test_milestone275/gt_test_milestone275.runs/impl_1/gt_test_milestone275.bit
        set expected 92cf91bbfd2214f0349cb6155c527eddf198268a03585d25fbe715e84d90d08e
        set elf $root/build/firmware275/gt_test_milestone275.elf
        if {[lindex [exec sha256sum $elf] 0] ne "b72ac12cfa79d4e43d3b119eff74f1da7fa8b77b925a31618caa4576f5a58adf"} {error "ELF hash mismatch"}
    }
    v13 {
        set bitfile $root/build/gt_test_milestone3_v13/gt_test_milestone3_v13.runs/impl_1/gt_test_milestone3_v13.bit
        set expected 1f73d7cb63573b0d36a59981bbc80118631c475cce1046400f3e2cbd7480ea9c
        set elf $root/build/firmware_milestone3_v13/gt_test_milestone3_v13.elf
        if {[lindex [exec sha256sum $elf] 0] ne "b366c8ad91f4c030ba177ea5231bb941ebd7fa26af981abe1cd578ecc9a67e29"} {error "ELF hash mismatch"}
    }
    v14 {
        set bitfile $root/build/gt_test_milestone3_v14/gt_test_milestone3_v14.runs/impl_1/gt_test_milestone3_v14.bit
        set expected 02633d63dce3e75b4e80de537341b89d7e6aa964ee6b710b8e3432e2ad665931
        set elf $root/build/firmware_milestone3_v14/gt_test_milestone3_v14.elf
        if {[lindex [exec sha256sum $elf] 0] ne "d8eecdb9b84c9d0395e6a0a06f5f84d0add22b6622e2dc6566e3f87afa2a41c9"} {error "ELF hash mismatch"}
    }
    v15 {
        set bitfile $root/build/gt_test_milestone3_v15/gt_test_milestone3_v15.runs/impl_1/gt_test_milestone3_v15.bit
        set expected 789c668c7bcf2bf30ac9046b6a6546819c64e4f64c8d81955431245a8a14b7f3
        set elf $root/build/firmware_milestone3_v15/gt_test_milestone3_v15.elf
        if {[lindex [exec sha256sum $elf] 0] ne "b62b160c483aac2a7d323d2e1307977bdb39483bbc117f9e3f09c6a269006391"} {error "ELF hash mismatch"}
    }
    firefly1_loopback_v1 {
        set bitfile $root/build/gt_test_firefly1_loopback_v1/gt_test_firefly1_loopback_v1.bit
        set expected 805b7062a3a0243536784ce546fa630ab3c91050a6be08ce2921a7b7d2fe64ec
        set elf $root/build/firmware_firefly1_loopback_v1/gt_test_firefly1_loopback_v1.elf
        if {[lindex [exec sha256sum $elf] 0] ne "211e3976707dac22b9cb4b8949ee0acd5f93a45ab2138cd6e83ac82f171bd788"} {error "ELF hash mismatch"}
    }
    firefly1_loopback_v2 {
        # Corrected q121--q123 functional FireFly-1 PMA-loopback image.
        # V1 is invalid and remains a distinct, forbidden target.
        set bitfile $root/build/gt_test_firefly1_loopback_v2/gt_test_firefly1_loopback_v2.bit
        set expected 098cf83f130fca3e5c084065f9aa3bf47655f399a45bb52d4b3f09a7ee06e4a9
        set elf $root/build/firmware_firefly1_loopback_v2/gt_test_firefly1_loopback_v2.elf
        if {[lindex [exec sha256sum $elf] 0] ne "ff01323bc6f96ea3caaef2c6ce3d94c6371c152a9cb3dead0e695a860f87219e"} {error "ELF hash mismatch"}
    }
    firefly1_loopback_v3 {
        # Polarity-corrected q121--q123 functional FireFly-1 PMA-loopback image.
        set bitfile $root/build/gt_test_firefly1_loopback_v3/gt_test_firefly1_loopback_v3.bit
        set expected 571d8502b576ce7cc0015ca6e5b9dd4c4a1b93dce2b1640ccfdf34a6e20db948
        set elf $root/build/firmware_firefly1_loopback_v3/gt_test_firefly1_loopback_v3.elf
        if {[lindex [exec sha256sum $elf] 0] ne "c140be06c6905eb806ee2a9d91bc549948c6555754e12d37bfaf7a801051af84"} {error "ELF hash mismatch"}
    }
    firefly1_loopback_v4 -
    firefly1_loopback_v4_f2 {
        # Clean-synthesized and independently audited PMA/reset-ack repair.
        set bitfile $root/build/gt_test_firefly1_loopback_v4/gt_test_firefly1_loopback_v4.bit
        set expected cc450c14786a2a00fca7ad844d47be7e5438d160590b463f8f2bd85ffc17443a
        set elf $root/build/firmware_firefly1_loopback_v4/gt_test_firefly1_loopback_v4.elf
        if {[lindex [exec sha256sum $elf] 0] ne "abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2"} {error "ELF hash mismatch"}
    }
    firefly1_loopback_v5 -
    firefly1_loopback_v5_f2 {
        # Independent bounded TX sessions; both sites use this exact image.
        set bitfile $root/build/gt_test_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.bit
        set expected a1014f7d2451045ae6fbae66f0d2d1faef60d74c4a74190584be20b6a821f28e
        set elf $root/build/firmware_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.elf
        if {[lindex [exec sha256sum $elf] 0] ne "37972efc9f7cd65ff2bd2569bd6b776bec0263d2ad00a32e9c3de2975ab06528"} {error "ELF hash mismatch"}
    }
    direct_quad_v6_f1 {
        set bitfile $root/build/gt_test_direct_quad_v6_f1/gt_test_direct_quad_v6_f1.bit
        set expected 06501f6d69a84d80fb47521b8835ea542dab3b6edaca42c8defa742f51b83dcc
        set elf $root/build/firmware_direct_quad_v6_f1/gt_test_direct_quad_v6_f1.elf
        if {[lindex [exec sha256sum $elf] 0] ne "262bbdf17844694d124e345b0f71b599dd57800dbf93ecc8c8ea35bb25611568"} {error "ELF hash mismatch"}
    }
    direct_quad_v6_f2 {
        set bitfile $root/build/gt_test_direct_quad_v6_f2/gt_test_direct_quad_v6_f2.bit
        set expected 5a7e5f3dabd7165baeb25ad920652bd9bfa017f741371ef1f1c82516cc37cfa9
        set elf $root/build/firmware_direct_quad_v6_f2/gt_test_direct_quad_v6_f2.elf
        if {[lindex [exec sha256sum $elf] 0] ne "ea7d79aca4e5edde9f0cf3ccd45644e9ceb722a71706ba077af35d432cf7a52a"} {error "ELF hash mismatch"}
    }
    direct_all_v8_f1 -
    direct_all_v8_f2 {
        # Symmetric all-direct cleanup-repair image; endpoint names keep
        # programming explicit and preserve the failed 0x00020404 release.
        set bitfile $root/build/gt_test_direct_all_v7r3/gt_test_direct_all_v7r3.bit
        set expected 698b44c2211e482142f38aab5b79d1cb9def7a79b2afe2450670b3e252f1a276
        set elf $root/build/firmware_direct_all_v7/gt_test_direct_all_v7.elf
        if {[lindex [exec sha256sum $elf] 0] ne "e746cf57db40b3f36a36ae749b3c73a4133fdef2486b137488c5079e05eae727"} {error "ELF hash mismatch"}
    }
    direct_all_v9_f1 -
    direct_all_v9_f2 {
        # Symmetric post-PMA IDLE-guard image.  The guard masks only the tail
        # of intentional PMA cleanup; the next acquisition requalifies RX.
        set bitfile $root/build/diagnostic_archive/direct-all-v9-0x00020406-external-failure/gt_test_direct_all_v7r3.bit
        set expected e81de4351f4c08b7485d4e70b441fbcfafe0db0763a6a41f331bc07febfe5ef9
        set elf $root/build/diagnostic_archive/direct-all-v9-0x00020406-external-failure/firmware_direct_all_v7/gt_test_direct_all_v7.elf
        if {[lindex [exec sha256sum $elf] 0] ne "a63b7dd19e571f4a76b5ab8e6179b43ac7017bc4ab42d8afb5ef026e5f2d23b0"} {error "ELF hash mismatch"}
    }
    direct_all_v10_f1 -
    direct_all_v10_f2 {
        # Symmetric TX-session acknowledgement and post-cleanup guard repair.
        set bitfile $root/build/diagnostic_archive/direct-all-v10-0x00020407-q231-capture-done-failure/gt_test_direct_all_v7r3.bit
        set expected 220e27906cb3433527420615b9e3fa61a26cf2954c365596394cb6e4f615f458
        set elf $root/build/diagnostic_archive/direct-all-v10-0x00020407-q231-capture-done-failure/firmware_direct_all_v7/gt_test_direct_all_v7.elf
        if {[lindex [exec sha256sum $elf] 0] ne "c4893050ae26e28ad09b1bd85f7dbce106812400d50dc658052a53fe6917a151"} {error "ELF hash mismatch"}
    }
    direct_all_v11_f1 -
    direct_all_v11_f2 {
        # V10 capture-complete RX-reset guard repair; both sites use the same
        # independently audited compressed image.
        set bitfile $root/build/diagnostic_archive/direct-all-v11-0x00020408-post-capture-aggregate-timeout/gt_test_direct_all_v7r3.bit
        set expected d0432ec4999b8c08e6515a8493e71f1a2fb0effd5d5f548799aee7f45c17afde
        set elf $root/build/diagnostic_archive/direct-all-v11-0x00020408-post-capture-aggregate-timeout/firmware_direct_all_v7/gt_test_direct_all_v7.elf
        if {[lindex [exec sha256sum $elf] 0] ne "35f310112418d5dfb309c5fe6696e8bb6762a45939f3d6cedbfa66802619f05f"} {error "ELF hash mismatch"}
    }
    direct_all_v12_f1 -
    direct_all_v12_f2 {
        # Per-lane post-capture requalification; both sites use the same
        # independently audited compressed image.
        set bitfile $root/build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/gt_test_direct_all_v7r3.bit
        set expected 5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697
        set elf $root/build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/firmware_direct_all_v7/gt_test_direct_all_v7.elf
        if {[lindex [exec sha256sum $elf] 0] ne "a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163"} {error "ELF hash mismatch"}
    }
    all_links_v2_f1 -
    all_links_v2_f2 {
        # Timing-clean, independently audited all-links-v2 image. Both sites
        # use the same compressed BIT and matching firmware ELF.
        set bitfile $root/build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/artifacts/gt_test_all_links_v2_timing_hardened_control_boundary_fix.bit
        set expected 163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f
        set elf $root/build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/artifacts/gt_test_all_links_v2.elf
        if {[lindex [exec sha256sum $elf] 0] ne "d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c"} {error "ELF hash mismatch"}
    }
    right221_223_proof {
        # Isolated native q221/q222/q223 dedicated-refclk and independent
        # reset-controller proof.  No MCU/firmware interface is present.
        set bitfile $root/build/gt_native_right221_223_threecore_proof_v1/gt_native_right221_223_threecore_proof_v1.bit
        set expected b72e5dad1d6491fe263cb8fffcdd957d5811ab25f7285e7eeae655ea1138f375
    }
    right221_223_managed_proof {
        # Isolated native q221/q222/q223 proof with three live quad
        # supervisors.  It has no MCU/firmware interface.
        set bitfile $root/build/gt_native_right221_223_managed_proof_v1/gt_native_right221_223_managed_proof_v1.bit
        set expected 25933b994967752606cdc03919beb498ae46da24f7d0460e61425838d3d8c5d7
    }
    golden {
        # Explicit user exception for this exact historical uncompressed image.
        set bitfile $root/build/vu13p_ibert_25g.runs/impl_1/top.bit
        set expected e6f49cef8ff91381ca2470c9b4860e90d13ea5ed98e48562ff14288365541e83
    }
    default {error "Unsupported image"}
}
if {[lindex [exec sha256sum $bitfile] 0] ne $expected} {error "Bitstream hash mismatch"}
connect -xvc-url TCP:apollo3010-1:2542
after 2000
set listing [targets]
puts $listing
set fpgas [regexp -all -inline -line {^\s*[0-9]+\*?\s+xcvu13p\s*$} $listing]
if {[llength $fpgas] != 2 || ![regexp -line {^\s*1\*?\s+xcvu13p\s*$} $listing]} {
    error "Unexpected JTAG chain: require two xcvu13p devices and F1 target 1"
}
set site F1
set target 1
if {[lindex $argv 0] eq "all_links_v2_f2"} {
    # After a board power cycle the unconfigured F2 is target 2 while the
    # freshly configured F1 debug children are targets 3/4.  If both sites
    # were already configured, F2 is target 4.  Accept only these two exact
    # xcvu13p positions; the chain-wide two-FPGA check above still applies.
    if {[regexp -line {^  2\s+xcvu13p\s*$} $listing]} {
        set target 2
    } elseif {[regexp -line {^  4\s+xcvu13p\s*$} $listing]} {
        set target 4
    } else {
        error "F2 preflight topology changed: expected xcvu13p target 2 or 4"
    }
    set site F2
} elseif {[lindex $argv 0] in {firefly1_loopback_v4_f2 firefly1_loopback_v5_f2 direct_quad_v6_f2 direct_all_v8_f2 direct_all_v9_f2 direct_all_v10_f2 direct_all_v11_f2 direct_all_v12_f2}} {
    # F1 exposes MDM/MicroBlaze children, placing the second FPGA at 4. Refuse any
    # changed topology rather than guessing which device to overwrite.
    if {![regexp -line {^  4\s+xcvu13p\s*$} $listing]} {
        error "F2 preflight topology changed: expected second FPGA target 4"
    }
    set site F2
    set target 4
}
targets $target
puts "PROGRAM_$site image=[lindex $argv 0] sha256=$expected time=[clock seconds]"
fpga -file $bitfile
after 2000
puts [targets]
puts "PROGRAM_${site}_COMPLETE time=[clock seconds]; verify loaded identity separately"
exit
