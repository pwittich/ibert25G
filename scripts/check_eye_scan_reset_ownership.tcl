# Post-route proof for equivalent first-stage bank reset reassignment.
# Native wrapper reset fanout remains behind its retained local second stage.
namespace eval eye_reset_audit {
  variable report
  variable equivalent 0
  variable signature
  variable publication_aliases 0
  variable quad_input_aliases 0

  proc driver {cell pin} {
    set net [get_nets -of_objects [get_pins $cell/$pin]]
    set drivers [get_pins -leaf -of_objects $net -filter {DIRECTION == OUT}]
    if {[llength $drivers] != 1} {error "Nonunique $cell/$pin driver"}
    return [get_property NAME $drivers]
  }
  proc check_register {cell} {
    if {[get_property REF_NAME $cell] ne "FDRE" || [get_property INIT $cell] ne "1'b0"} {
      error "Unexpected synchronous reset release register $cell"
    }
    # Implemented inversion belongs to the physical pin, not the optional
    # (empty after implementation) IS_C_INVERTED cell parameter.
    foreach pin {D C CE R} {
      if {[get_property IS_INVERTED [get_pins $cell/$pin]] ni {0 false FALSE}} {
        error "Unexpected inverted reset-release pin $cell/$pin"
      }
    }
    foreach pin {CE R} expected {POWER GROUND} {
      if {[get_property TYPE [get_nets -of_objects [get_pins $cell/$pin]]] ne $expected} {
        error "Unexpected $cell/$pin control"
      }
    }
  }
  proc initialize {directory} {
    variable report;variable equivalent;variable signature
    variable publication_aliases;variable quad_input_aliases
    set publication_aliases 0;set quad_input_aliases 0
    set report [open [file join $directory reset_ownership.rpt] w]
    set releases [get_cells -hier -quiet -filter {NAME =~ *g_bank_slr*/local_resetn_reg && REF_NAME =~ FD*}]
    if {[llength $releases] != 4} {error "Missing bank reset releases"}
    set signatures {}
    foreach c $releases {
      check_register $c
      set item [list [driver $c D] [driver $c C]]
      lappend signatures $item
      puts $report "BANK_RELEASE $c INIT=0 CE=1 R=0 C_INV=0 drivers=$item"
    }
    set equivalent [expr {[llength [lsort -unique $signatures]] == 1}]
    set signature [lindex $signatures 0]
    puts $report "ALL_FOUR_CYCLE_EQUIVALENT=$equivalent"
  }
  proc check_loads {bank reset_reg} {
    variable report;variable equivalent;variable signature
    variable publication_aliases;variable quad_input_aliases
    set bank_name [get_property NAME $bank]
    set q [get_pins $reset_reg/Q]
    set loads [get_pins -leaf -of_objects [get_nets -of_objects $q] -filter {DIRECTION == IN}]
    if {![llength $loads]} {error "Bank reset has no routed loads: $reset_reg"}
    foreach load $loads {
      set name [get_property NAME $load]
      if {[string match "$bank_name/*" $name]} {continue}
      if {!$equivalent} {error "Cross-bank reset drive without cycle equivalence: $load"}
      set target [get_cells -of_objects $load]
      if {[regexp {^(.*g_bank_slr([0-3]))/g_localize_quad_reset\.(left|right)_quad_resetn_reg\[([0-9]+)\]/D$} $name -> destination slr side index]} {
        # Only the D of a retained second-stage release may be reassigned.
        # Its own Q must still drive exclusively the original local wrapper.
        check_register $target
        if {[driver $target C] ne [lindex $signature 1] ||
            [string tolower [get_property KEEP $target]] ni {true 1 yes} ||
            [get_property NAME [get_slrs -of_objects [get_sites -of_objects $target]]] ne "SLR$slr"} {
          error "Cross-bank second-stage reset lost clock/KEEP/residency: $load"
        }
        set wrapper "$destination/g_${side}_quad\[$index\].u_managed_$side"
        set local_loads [get_pins -leaf -of_objects [get_nets -of_objects [get_pins $target/Q]] -filter {DIRECTION == IN}]
        if {![llength $local_loads]} {error "Localized reset has no wrapper loads: $target"}
        foreach local $local_loads {
          if {[string first "$wrapper/" [get_property NAME $local]] != 0} {
            error "Localized second-stage reset escaped its wrapper: $local"
          }
        }
        puts $report "LOCAL_QUAD_RELEASE $target SLR=$slr wrapper=$wrapper loads=[llength $local_loads]"
        incr quad_input_aliases
        set kind SECOND_STAGE_D
      } elseif {[regexp {^(.*g_bank_slr([0-3]))/u_local_aggregate/diagnostics_reg\[[0-9]+\]/R$} $name -> destination slr]} {
        set ends [all_fanout -flat -endpoints_only -from [get_pins $target/Q]]
        if {![llength $ends]} {error "Diagnostic alias has no publication endpoints: $target"}
        foreach end $ends {
          if {![regexp {g_status_return\[([0-3])\]\.u_return/stage_one_reg\[([0-9]+)\]/D$} [get_property NAME $end] -> output_bank bit] ||
              $output_bank != $slr || $bit < 13 || $bit > 236} {
            error "Diagnostic reset alias feeds a control endpoint: $end"
          }
        }
        incr publication_aliases
        set kind DIAGNOSTIC_R
      } else {
        error "Unqualified bank reset escape: $load"
      }
      set setup [get_timing_paths -quiet -from $q -to $load -max_paths 1]
      set hold [get_timing_paths -quiet -delay_type min -from $q -to $load -max_paths 1]
      if {[llength $setup] != 1 || [get_property SLACK $setup] < 0 ||
          abs([get_property REQUIREMENT $setup]-5.0)>0.001 ||
          [llength $hold] != 1 || [get_property SLACK $hold] < 0} {
        error "Equivalent reset reassignment lacks ordinary setup/hold timing: $load"
      }
      puts $report "QUALIFIED_ALIAS $kind source=$reset_reg target=$load setup=[get_property SLACK $setup] hold=[get_property SLACK $hold]"
    }
  }
  proc finish {} {
    variable report;variable publication_aliases;variable quad_input_aliases
    puts $report "publication_aliases=$publication_aliases quad_input_aliases=$quad_input_aliases"
    close $report
    puts "PASS: reset waveform/ownership proof; diagnostic aliases=$publication_aliases, second-stage D aliases=$quad_input_aliases"
  }
}
