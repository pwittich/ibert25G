#!/usr/bin/env python3
"""Force and verify one v2.5.9 acquisition-time full-quad restart.

Program the isolated Milestone 2.5.9 image immediately before running this
script. FireFly-5 channel 0 remains disabled for 250 ms, spanning the fixed
100-ms restart trigger even when the short restart state cannot be sampled
over MCU I2C. The script then requires one clean ten-second four-lane
measurement. It commits exactly one request and always restores byte 86.
"""

from pathlib import Path
import sys
import time

import milestone3_12hour_external_soak as test


VERSION = 0x00020109
CANDIDATE_LABEL = "2.5.9"
SEQUENCE = 1
DURATION_MS = 10_000
RESTORE_AFTER_SECONDS = 0.250
FIREFLY_ADDRESS = 0x28
TX_DISABLE_REGISTER = 0x56
LOS_ALARM_REGISTER = 0x03
CDR_LOL_ALARM_REGISTER = 0x05
CHANNEL_MASK = 0x01


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    package_parent = str(Path("/home/cms/25G/cm_interface").resolve().parent)
    if package_parent not in sys.path:
        sys.path.insert(0, package_parent)
    from cm_interface.device.firefly import Firefly4
    from cm_interface.registry import Registry

    registry = Registry(setup="tf", dev_path="/dev/ttyUL4")
    mailbox = test.FpgaMailbox(registry.fpgas["F1"])
    firefly = Firefly4(registry.uart, FIREFLY_ADDRESS, "F1_5")
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION

    overview = test.read_overview(mailbox)
    test.expect("firmware version", overview["firmware version"], VERSION)
    test.expect("hardware version", overview["hardware version"], VERSION)
    test.expect("engine state", overview["engine state"], 0)
    test.expect("request sequence", overview["request sequence"], 0)
    test.expect("response sequence", overview["response sequence"], 0)
    test.expect("preflight run ID", overview["hardware run ID"], 0)

    original = firefly.read_reg(TX_DISABLE_REGISTER)[0]
    require(not (original & CHANNEL_MASK),
            "FireFly channel 0 is already disabled (byte 86 = 0x{:02x})".format(
                original))
    # Clear read-to-clear latch history before applying this stimulus.
    firefly.read_reg(LOS_ALARM_REGISTER)
    firefly.read_reg(CDR_LOL_ALARM_REGISTER)

    descriptor = {
        test.REG_COMMAND: test.COMMAND_EXTERNAL_PRBS31_MS,
        test.REG_DURATION: DURATION_MS,
        test.REG_TIMEOUT: 0,
        test.REG_MASK_0: test.MANAGED_LANE_MASK,
        test.REG_MASK_1: 0,
        test.REG_MASK_2: 0,
        test.REG_MASK_3: 0,
    }
    restored = False
    request_committed = False
    saw_restart = False
    state_history = []
    start_time = None
    try:
        firefly.write_reg(TX_DISABLE_REGISTER,
                          bytes([original | CHANNEL_MASK]))
        require(firefly.read_reg(TX_DISABLE_REGISTER)[0] ==
                (original | CHANNEL_MASK),
                "FireFly TX-disable readback mismatch")
        time.sleep(0.1)
        active_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
        active_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
        print("disabled LOS/LOL = 0x{:02x}/0x{:02x}".format(
            active_los, active_lol))
        require(active_los & 0x01, "FireFly RX0 LOS did not assert")
        require(active_los & 0x10, "FireFly TX0 LOS did not assert")
        require(active_lol & 0x01, "FireFly RX0 CDR LOL did not assert")

        print("Writing and verifying forced-restart descriptor:")
        for address, value in descriptor.items():
            mailbox.write_u32(address, value)
        for address, expected in descriptor.items():
            test.expect("register {:#04x}".format(address),
                        mailbox.read_u32(address), expected)

        # Keep the diagnostic selector fixed while polling the live PRBS word.
        mailbox.write_u8(test.REG_RESULT_LANE, test.DIAGNOSTIC_SELECTOR)
        mailbox.write_u32(test.REG_REQUEST_SEQUENCE, SEQUENCE)
        request_committed = True
        start_time = time.monotonic()
        deadline = start_time + 15.0
        previous_state = None
        while True:
            engine = mailbox.read_u32(test.REG_ENGINE_STATE)
            live_prbs = mailbox.read_u32(test.REG_LANE_RECORD + 4)
            prbs_state = live_prbs & 0x1F
            elapsed = time.monotonic() - start_time
            if prbs_state != previous_state:
                print("t={:.6f}s PRBS state {} ({})".format(
                    elapsed, prbs_state,
                    test.PRBS_STATES.get(prbs_state, "UNKNOWN")))
                state_history.append(prbs_state)
                previous_state = prbs_state

            if prbs_state in (23, 24):
                saw_restart = True
            # States 23/24 can complete between two MCU/I2C samples. Keep the
            # outage beyond the fixed 100-ms trigger, then restore on elapsed
            # time so the post-restart checker can acquire the returned link.
            if elapsed >= RESTORE_AFTER_SECONDS and not restored:
                firefly.write_reg(TX_DISABLE_REGISTER, bytes([original]))
                require(firefly.read_reg(TX_DISABLE_REGISTER)[0] == original,
                        "FireFly byte 86 restore readback mismatch")
                restored = True
                print("t={:.6f}s restored FireFly byte 86 after the "
                      "100-ms restart trigger".format(
                          time.monotonic() - start_time))

            if engine & test.PLATFORM_FAULT_BIT:
                test.print_platform_diagnostics(mailbox)
                raise RuntimeError("platform fault during forced restart")
            # Do not let an unexpectedly early RUN exit bypass the scheduled
            # restore; that would turn the intended acquisition stimulus into
            # an in-measurement error injection.
            if (engine & 0xF) == test.STATE_RUN and restored:
                break
            require(time.monotonic() < deadline,
                    "timed out waiting for RUN; PRBS states were {}".format(
                        state_history))
            time.sleep(0.002)
    finally:
        if not restored:
            firefly.write_reg(TX_DISABLE_REGISTER, bytes([original]))
            restored = firefly.read_reg(TX_DISABLE_REGISTER)[0] == original
            print("restored FireFly byte 86 in cleanup: {}".format(restored))

    require(restored, "failed to restore FireFly byte 86")
    require(request_committed, "request was not committed")
    if saw_restart:
        print("Directly observed coordinated restart state 23/24.")
    else:
        print("Restart state completed between MCU samples; the outage was "
              "held {:.0f} ms across the fixed 100-ms trigger.".format(
                  RESTORE_AFTER_SECONDS * 1000.0))
    print("Waiting for HDL completion.")

    deadline = time.monotonic() + DURATION_MS / 1000.0 + 10.0
    while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != SEQUENCE:
        require(time.monotonic() < deadline, "timed out waiting for completion")
        time.sleep(0.25)
    test.check_results(mailbox, SEQUENCE,
                       "{} forced full-quad restart acceptance".format(
                           CANDIDATE_LABEL),
                       test.MANAGED_LANE_MASK)
    test.expect("completed run ID", mailbox.read_u32(test.REG_RUN_ID), 1)
    print("MILESTONE {} FORCED FULL-QUAD RESTART ACCEPTANCE PASSED".format(
        CANDIDATE_LABEL))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
