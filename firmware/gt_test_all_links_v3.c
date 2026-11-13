#include <stdint.h>
#include "gt_test_engine_regs.h"

#define GTTE_BASE 0x44a00000u

#ifndef GTTE_FIRMWARE_VERSION
#define GTTE_FIRMWARE_VERSION 0x00010002u
#endif
#ifndef GTTE_MANAGED_MASK0
#define GTTE_MANAGED_MASK0 0xffffffffu
#define GTTE_MANAGED_MASK1 0xffffffffu
#define GTTE_MANAGED_MASK2 0xffffffffu
#define GTTE_MANAGED_MASK3 0x0000ffffu
#endif

static volatile uint32_t job_complete;
static volatile uint32_t job_interrupt_status;

static inline uint32_t mmio_read(uint32_t base, uint32_t offset)
{
  return *(volatile uint32_t *)(uintptr_t)(base + offset);
}

static inline void mmio_write(uint32_t base, uint32_t offset, uint32_t value)
{
  *(volatile uint32_t *)(uintptr_t)(base + offset) = value;
}

static inline void enable_interrupts(void)
{
  __asm__ volatile ("msrset r0, 2" ::: "memory");
}

static inline void disable_interrupts(void)
{
  __asm__ volatile ("msrclr r0, 2" ::: "memory");
}

static inline void wait_for_interrupt(void)
{
  __asm__ volatile ("sleep" ::: "memory");
}

void __attribute__((interrupt_handler)) gt_test_interrupt_handler(void)
{
  job_interrupt_status = mmio_read(GTTE_BASE,
                                   GTTE_REG_INTERRUPT_STATUS);
  mmio_write(GTTE_BASE, GTTE_REG_DOORBELL,
             GTTE_DOORBELL_CLEAR_INTERRUPT);
  job_complete = 1u;
}

static int validate_request(uint32_t command, uint32_t duration,
                            uint32_t mask0, uint32_t mask1,
                            uint32_t mask2, uint32_t mask3)
{
  uint32_t opcode = command & 0xffu;
  uint32_t prbs = (command >> 8) & 7u;
  uint32_t loopback = (command >> 11) & 7u;
  uint32_t allowed_bits = 0x00013fffu;
  uint32_t loopback_valid = loopback == 0u || loopback == 1u ||
                            loopback == 2u || loopback == 4u ||
                            loopback == 6u;
  return (command & ~allowed_bits) == 0u && loopback_valid &&
         opcode == GTTE_OPCODE_PARALLEL_BER && prbs >= GTTE_PRBS7 &&
         prbs <= GTTE_PRBS31 && duration != 0u &&
         (mask0 | mask1 | mask2 | (mask3 & 0xffffu)) != 0u &&
         (mask0 & ~GTTE_MANAGED_MASK0) == 0u &&
         (mask1 & ~GTTE_MANAGED_MASK1) == 0u &&
         (mask2 & ~GTTE_MANAGED_MASK2) == 0u &&
         (mask3 & ~GTTE_MANAGED_MASK3) == 0u;
}

int main(void)
{
  uint32_t handled_sequence = 0u;

  mmio_write(GTTE_BASE, GTTE_MAILBOX_FIRMWARE_VERSION,
             GTTE_FIRMWARE_VERSION);
  enable_interrupts();

  for (;;) {
    uint32_t sequence = mmio_read(GTTE_BASE,
                                  GTTE_MAILBOX_REQUEST_SEQUENCE);
    if (sequence == handled_sequence)
      continue;

    uint32_t command = mmio_read(GTTE_BASE, GTTE_MAILBOX_COMMAND);
    uint32_t duration = mmio_read(GTTE_BASE, GTTE_MAILBOX_DURATION);
    uint32_t timeout = mmio_read(GTTE_BASE, GTTE_MAILBOX_TIMEOUT);
    uint32_t mask0 = mmio_read(GTTE_BASE, GTTE_MAILBOX_LANE_MASK_0 + 0u);
    uint32_t mask1 = mmio_read(GTTE_BASE, GTTE_MAILBOX_LANE_MASK_0 + 4u);
    uint32_t mask2 = mmio_read(GTTE_BASE, GTTE_MAILBOX_LANE_MASK_0 + 8u);
    uint32_t mask3 = mmio_read(GTTE_BASE, GTTE_MAILBOX_LANE_MASK_0 + 12u);

    /* v3 atomic quad configuration uses the existing sequence-last mailbox.
     * It never touches run IDs or published receive records. */
    if (command == 4u) {
      uint32_t state = mmio_read(GTTE_BASE, GTTE_REG_STATE);
      uint32_t session = mmio_read(GTTE_BASE, 0x104u);
      uint32_t valid = (state & 0xfu) == 0u && !(session & 1u) &&
        duration == 0u && timeout == 0u && mask2 == 0u && mask3 == 0u &&
        (mask0 & 0xf0000000u) == 0u && (mask1 & 0xf0000000u) == 0u;
      if (valid) {
        uint32_t polls = 0u, status;
        mmio_write(GTTE_BASE, 0x120u, mask0);
        mmio_write(GTTE_BASE, 0x124u, mask1);
        mmio_write(GTTE_BASE, 0x128u, 1u);
        do {
          status = mmio_read(GTTE_BASE, 0x12cu);
          polls++;
        } while ((status & 2u) && polls < 50000000u);
        valid = status == 9u; /* applied, usable, no error */
      }
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_CODE, valid ? 0u : 1u);
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_SEQUENCE, sequence);
      handled_sequence = sequence;
      continue;
    }

#ifdef GTTE_ENABLE_TX_SESSION
    /* Versioned session commands: fixed managed-lane PRBS31 TX lease; no run-ID
     * increment and no modification of captured receive records. */
    if (command == 2u || command == 3u) {
      uint32_t state = mmio_read(GTTE_BASE, 0x010u);
      uint32_t session = mmio_read(GTTE_BASE, 0x104u);
      uint32_t valid = (state & 0x1ffffu) == 0u && timeout == 0u &&
                       mask0 == GTTE_MANAGED_MASK0 &&
                       mask1 == GTTE_MANAGED_MASK1 &&
                       mask2 == GTTE_MANAGED_MASK2 &&
                       mask3 == GTTE_MANAGED_MASK3;
      if (command == 2u)
        valid = valid && duration > 0u && duration <= 86400000u && !(session & 1u);
      else
        valid = valid && duration == 0u;
      if (valid) {
        uint32_t polls = 0u;
        if (command == 2u) mmio_write(GTTE_BASE, 0x10cu, duration);
        mmio_write(GTTE_BASE, 0x100u, command == 2u ? 1u : 2u);
        do {
          session = mmio_read(GTTE_BASE, 0x104u);
          polls++;
        } while (polls < 1000000u && !(session & 4u) &&
                 (command == 2u ? (session & 0x11u) != 0x11u
                                : (session & 0x11u) != 0u));
        valid = !(session & 4u) &&
          (command == 2u ? (session & 0x11u) == 0x11u
                         : (session & 0x11u) == 0u);
        // Never leave an unacknowledged transmitter lease running. A failed
        // start is fail-closed and cannot be followed by an RX descriptor.
        if (!valid && command == 2u) mmio_write(GTTE_BASE, 0x100u, 2u);
      }
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_CODE, valid ? 0u : 1u);
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_SEQUENCE, sequence);
      handled_sequence = sequence;
      continue;
    }
#endif

    if (!validate_request(command, duration, mask0, mask1, mask2, mask3)) {
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_CODE, 1u);
      mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_SEQUENCE, sequence);
      handled_sequence = sequence;
      continue;
    }

    mmio_write(GTTE_BASE, GTTE_REG_DESCRIPTOR_CONTROL, command);
    mmio_write(GTTE_BASE, GTTE_REG_DURATION_CYCLES, duration);
    mmio_write(GTTE_BASE, GTTE_REG_TIMEOUT_CYCLES, timeout);
    mmio_write(GTTE_BASE, GTTE_REG_LANE_MASK_0, mask0);
    mmio_write(GTTE_BASE, GTTE_REG_LANE_MASK_1, mask1);
    mmio_write(GTTE_BASE, GTTE_REG_LANE_MASK_2, mask2);
    mmio_write(GTTE_BASE, GTTE_REG_LANE_MASK_3, mask3 & 0xffffu);

    job_complete = 0u;
    job_interrupt_status = 0u;
    mmio_write(GTTE_BASE, GTTE_REG_DOORBELL, GTTE_DOORBELL_START);

    /*
     * Close the check-to-sleep race with interrupts masked.  Wakeup is a
     * discrete level input and remains effective while IE is clear.  Once the
     * engine level wakes the pipeline, enabling interrupts services the
     * pending ISR before the following instruction; the ISR clears the level
     * and sets job_complete.  An MDM-only wake simply loops back to sleep.
     */
    disable_interrupts();
    while (!job_complete) {
      wait_for_interrupt();
      enable_interrupts();
      disable_interrupts();
    }
    enable_interrupts();

    mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_CODE,
               (job_interrupt_status & 2u) != 0u
                 ? 1u : mmio_read(GTTE_BASE, GTTE_REG_SUMMARY));
    mmio_write(GTTE_BASE, GTTE_MAILBOX_RESPONSE_SEQUENCE, sequence);
    handled_sequence = sequence;
  }
}
