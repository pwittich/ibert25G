#ifndef GT_TEST_ENGINE_REGS_H
#define GT_TEST_ENGINE_REGS_H

#define GTTE_REG_HARDWARE_ID          0x000u
#define GTTE_REG_HARDWARE_VERSION     0x004u
#define GTTE_REG_CAPABILITIES         0x008u
#define GTTE_REG_DOORBELL             0x00cu
#define GTTE_REG_STATE                0x010u
#define GTTE_REG_INTERRUPT_STATUS     0x014u
#define GTTE_REG_RUN_ID               0x018u
#define GTTE_REG_SUMMARY              0x01cu
#define GTTE_REG_DESCRIPTOR_CONTROL   0x020u
#define GTTE_REG_DURATION_CYCLES      0x024u
#define GTTE_REG_TIMEOUT_CYCLES       0x028u
#define GTTE_REG_LANE_MASK_0          0x02cu
#define GTTE_REG_LANE_MASK_1          0x030u
#define GTTE_REG_LANE_MASK_2          0x034u
#define GTTE_REG_LANE_MASK_3          0x038u
#define GTTE_REG_RESULT_LANE          0x03cu
#define GTTE_REG_RESULT_WORD_0        0x040u
#define GTTE_REG_ERROR_INJECT_0       0x060u
#define GTTE_REG_PLATFORM_STATUS      0x070u
#define GTTE_REG_MANAGED_MASK_0       0x074u
#define GTTE_REG_PLATFORM_DIAG_LIVE   0x084u
#define GTTE_REG_PLATFORM_DIAG_RX     0x088u
#define GTTE_REG_PLATFORM_DIAG_QUAD   0x08cu
#define GTTE_REG_PLATFORM_FAULT_LIVE  0x090u
#define GTTE_REG_PLATFORM_FAULT_RX    0x094u
#define GTTE_REG_PLATFORM_FAULT_QUAD  0x098u
#define GTTE_REG_PLATFORM_FAULT_COUNT 0x09cu

#define GTTE_CONTROL_LOOPBACK_SHIFT   11u
#define GTTE_CONTROL_TIMEBASE_MS      (1u << 16)

#define GTTE_DOORBELL_START           (1u << 0)
#define GTTE_DOORBELL_ABORT           (1u << 1)
#define GTTE_DOORBELL_CLEAR_INTERRUPT (1u << 2)

#define GTTE_OPCODE_PARALLEL_BER      0x01u
#define GTTE_PRBS7                    1u
#define GTTE_PRBS9                    2u
#define GTTE_PRBS15                   3u
#define GTTE_PRBS23                   4u
#define GTTE_PRBS31                   5u

#define GTTE_MAILBOX_REQUEST_SEQUENCE 0x0a0u
#define GTTE_MAILBOX_COMMAND          0x0a4u
#define GTTE_MAILBOX_DURATION         0x0a8u
#define GTTE_MAILBOX_TIMEOUT          0x0acu
#define GTTE_MAILBOX_LANE_MASK_0      0x0b0u
#define GTTE_MAILBOX_FIRMWARE_VERSION 0x0c0u
#define GTTE_MAILBOX_HARDWARE_VERSION 0x0c4u
#define GTTE_MAILBOX_STATE            0x0c8u
#define GTTE_MAILBOX_RESULT_LANE      0x0ccu
#define GTTE_MAILBOX_RESULT_WORD_0    0x0d0u
#define GTTE_MAILBOX_RESPONSE_SEQUENCE 0x0f0u
#define GTTE_MAILBOX_RESPONSE_CODE    0x0f4u
#define GTTE_MAILBOX_RUN_ID           0x0f8u
#define GTTE_MAILBOX_SUMMARY          0x0fcu

#define GTTE_RESULT_SELECTOR_DIAGNOSTICS 0xfeu
#define GTTE_RESULT_SELECTOR_RECOVERY    0xfdu
#define GTTE_RECOVERY_SCHEMA             0x52430001u
#define GTTE_RECOVERY_CAP_RESTART        (1u << 0)
#define GTTE_RECOVERY_CAP_INTEGRITY      (1u << 1)
#define GTTE_RECOVERY_CAP_HEARTBEAT_TEST (1u << 2)

#endif
