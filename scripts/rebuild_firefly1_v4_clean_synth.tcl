set archive_name firefly1-v4-rejected-incremental-reset-ack
set prior_hash cd9c92cf2079cc728772427e62ff4667ba9e48cb2e912c28c8535d4027327d6c
set clean_synthesis 1
source [file join [file dirname [file normalize [info script]]] rebuild_firefly1_v4_pma_repair.tcl]
