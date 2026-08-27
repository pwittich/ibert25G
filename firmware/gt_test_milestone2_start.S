  .section .vectors,"ax"
  // The firmware build disables linker relaxation so the two-instruction
  // absolute branches cannot shrink and move the interrupt vector from 0x10.
  .global _start
  .org 0x00
  brai _start
  nop
  .org 0x10
  // MicroBlaze is configured for standard (non-vectored) interrupts, so every
  // direct engine interrupt enters through this fixed vector.
  brai gt_test_interrupt_handler
  nop

  .section .text.startup,"ax"
_start:
  addik r1, r0, _stack
  brlid r15, main
  nop
1:
  bri 1b
  nop
