#!/usr/bin/env python3
"""Start or validate the isolated 2.5.7 single-error characterization."""

import argparse
from pathlib import Path
import sys
import time

import milestone3_12hour_external_soak as test


VERSION = 0x00020107
CANDIDATE_LABEL = "2.5.7"
SUMMARY_ONE_FAILED_THREE_PASSED = 0x01030401


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("start", "results"))
    parser.add_argument("--sequence", type=lambda value: int(value, 0),
                        default=3)
    parser.add_argument("--previous-sequence",
                        type=lambda value: int(value, 0), default=2)
    parser.add_argument("--expected-run-id",
                        type=lambda value: int(value, 0), default=3)
    parser.add_argument("--duration-ms", type=lambda value: int(value, 0),
                        default=30000)
    parser.add_argument("--cm-interface-root", type=Path,
                        default=Path("/home/cms/25G/cm_interface"))
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument("--reg-module", default=None)
    parser.add_argument("--fpga", default="F1")
    return parser.parse_args()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate_results(mailbox, sequence, expected_run_id):
    deadline = time.monotonic() + 60.0
    while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != sequence:
        require(time.monotonic() < deadline, "timed out waiting for completion")
        time.sleep(0.25)

    overview = test.read_overview(mailbox)
    test.expect("firmware version", overview["firmware version"], VERSION)
    test.expect("hardware version", overview["hardware version"], VERSION)
    test.expect("engine state", overview["engine state"], 0)
    test.expect("response sequence", overview["response sequence"], sequence)
    test.expect("response code", overview["response code"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("hardware summary", overview["hardware summary"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("run ID", overview["hardware run ID"], expected_run_id)

    run_id_before = mailbox.read_u32(test.REG_RUN_ID)
    results = {lane: test.read_lane(mailbox, lane) for lane in range(12, 16)}
    test.expect("stable run ID", mailbox.read_u32(test.REG_RUN_ID), run_id_before)
    for lane, result in results.items():
        print("lane {}: status={:#010x} error_active_cycles={} losses={} "
              "bits={} cycles={}".format(
                  lane, result["id_status"], result["errors"],
                  result["lock_losses"], result["tested_bits"],
                  result["valid_cycles"]))
        require(result["tested_bits"] == result["valid_cycles"] * 80,
                "lane {} bit/cycle mismatch".format(lane))
        require(result["lock_losses"] == 0,
                "lane {} unexpectedly reported lock loss".format(lane))

    require(0 < results[12]["errors"] < 1000,
            "lane 12 transient count is outside 1-999 active cycles")
    for lane in range(13, 16):
        require(results[lane]["errors"] == 0,
                "adjacent lane {} recorded error activity".format(lane))
    print("MILESTONE %s SINGLE-ERROR CHARACTERIZATION PASSED" %
          CANDIDATE_LABEL)


def main():
    args = parse_args()
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION
    mailbox = test.load_mailbox(args)
    if args.stage == "start":
        test.expect("preflight run ID", mailbox.read_u32(test.REG_RUN_ID),
                    args.expected_run_id - 1)
        test.start_soak(mailbox, args.sequence, args.previous_sequence,
                        args.duration_ms,
                        "{} single-error characterization".format(
                            CANDIDATE_LABEL),
                        test.MANAGED_LANE_MASK)
    else:
        validate_results(mailbox, args.sequence, args.expected_run_id)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
