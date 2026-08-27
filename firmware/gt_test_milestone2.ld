ENTRY(_start)

MEMORY
{
  local_memory (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS
{
  .vectors 0x00000000 : { KEEP(*(.vectors)) } > local_memory
  .text : { *(.text.startup) *(.text*) *(.rodata*) } > local_memory
  .data : { *(.data*) } > local_memory
  .bss : { *(.bss*) *(COMMON) } > local_memory
  . = ALIGN(16);
  _stack = ORIGIN(local_memory) + LENGTH(local_memory) - 16;
}
