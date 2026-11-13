#!/usr/bin/env python3
"""On-blade v3 status/configure/external-test tool; no program/reset/retry."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback

from all_links_v3_contract import (VERSION, CM_COMMIT, quad_mask, receive_words, required_refclks,
                                  require_release, BIT_SHA256, DCP_SHA256, ELF_SHA256)
from all_links_v2_timed_common import (acquire_lock, load_registry, make_boxes,
    CLOCK_NAMES, telemetry_snapshot, require, wait_response)
from all_links_v2_timed_contract import (ALL_MASK, CAPABILITY, SESSION_ACTIVE,
    SESSION_READY, expected_cycles, mask_lanes, validate_duration)
from milestone3_12hour_external_soak import read_lane


def check_clocks(site, box, enabled):
    require(box.read_u32(0x9c) == 0x434da501, site + " clock ABI/valid status mismatch")
    values = {}
    for index, name in enumerate(CLOCK_NAMES):
        address = (index + 2) * 4
        values[address] = box.read_u32(address)
        print("CLOCK site=%s r=%02d name=%s khz=%d" %
              (site, index + 2, name, values[address]), flush=True)
    for address, nominal in ((0x08, 200000), (0x24, 100000), (0x28, 325000)):
        require(abs(values[address] - nominal) < nominal * .001, site + " fabric clock invalid")
    for address in required_refclks(enabled):
        require(abs(values[address] - 322266) < 323,
                "%s enabled GT REFCLK %#x invalid" % (site, address))
    require(box.read_u32(0x9c) == 0x434da501, site + " clock publication changed")


def predecessor(site, box, expected=None, allow_fault=False):
    addresses = (0xc0, 0xc4, 0xc8, 0xa0, 0xf0, 0xf8)
    first = tuple(box.read_u32(a) for a in addresses)
    second = tuple(box.read_u32(a) for a in addresses)
    require(first == second, site + " state changed during discovery")
    fw, hw, state, seq, ack, run = second
    require(fw == hw == VERSION, site + " v3 identity mismatch")
    require(state & 15 == 0 and not state & SESSION_ACTIVE, site + " busy/session active")
    if not allow_fault:
        require(state == CAPABILITY, site + " unhealthy IDLE")
    require(seq == ack and seq <= 0xfffffffc and run < 0xffffffff,
            site + " pending request or exhausted sequence/run")
    require(expected is None or expected == (seq, run), site + " explicit predecessor mismatch")
    print("PREDECESSOR site=%s sequence=%d run=%d" % (site, seq, run), flush=True)
    return seq, run


def configuration(site, box):
    box.write_u32(0xcc, 0xf7)
    words = tuple(box.read_u32(a) for a in range(0xd0, 0xf0, 4))
    require(words[0] == 0x51430001, site + " quad configuration schema mismatch")
    print("V3_CONFIG site=%s tx=%07x rx=%07x applied_tx=%07x applied_rx=%07x generation=%d state=%d eligible=%d error=%d" %
          ((site,) + words[1:6] + (words[6] & 7, int(bool(words[6] & 0x100)), words[7])), flush=True)
    return words


def submit(site, box, seq, command, duration, mask):
    require(box.read_u32(0xa0) == box.read_u32(0xf0) == seq, site + " predecessor changed")
    state = box.read_u32(0xc8)
    require(state & 15 == 0, site + " engine busy")
    if command != 4:
        require(state & 0x1ffff == 0, site + " platform fault")
    if command == 4:
        require(not state & SESSION_ACTIVE, site + " session active")
    fields = ((0xa4, command), (0xa8, duration), (0xac, 0)) + tuple(
        (0xb0 + 4 * i, word) for i, word in enumerate(mask))
    for address, value in fields:
        box.write_u32(address, value)
        require(box.read_u32(address) == value, site + " request readback mismatch")
    print("V3_SUBMIT site=%s sequence=%d command=%#x duration_ms=%d mask=%r" %
          (site, seq + 1, command, duration, mask), flush=True)
    box.write_u32(0xa0, seq + 1)
    return seq + 1


def configure(site, box, tx, rx, expected=None):
    seq, run = predecessor(site, box, expected, allow_fault=True)
    before = configuration(site, box)
    require(before[6] & 0x100, site + " cleanup or stop acknowledgement still pending")
    check_clocks(site, box, tx | rx)
    seq = submit(site, box, seq, 4, 0, (tx, rx, 0, 0))
    code = wait_response(site, box, seq, 5)
    after = configuration(site, box)
    require(code == 0 and after[1:5] == (tx, rx, tx, rx) and
            after[5] == (before[5] + 1) & 0xffffffff and (after[6] & 7) == 2 and after[7] == 0 and
            box.read_u32(0xf8) == run, site + " configuration failed; do not retry")


def validate_records(site, box, mask, expected_run, duration_ms):
    # Dump every selected record before judging the run, including failed runs.
    lanes = mask_lanes(mask)
    records = [(lane, read_lane(box, lane)) for lane in lanes]
    for lane, record in records:
        print("RECORD site=%s run=%d lane=%d data=%r" % (site, expected_run, lane, record), flush=True)
    summary = (len(lanes) << 16) | (len(lanes) << 8) | 1
    failures = []
    if box.read_u32(0xf4) != summary or box.read_u32(0xfc) != summary or box.read_u32(0xf8) != expected_run:
        failures.append("response/summary/run mismatch")
    target = expected_cycles(duration_ms)
    for lane, record in records:
        if (record["id_status"] != 0x1800 + lane or record["errors"] != 0 or
                record["lock_losses"] != 0 or
                record["tested_bits"] != record["valid_cycles"] * 80 or
                abs(record["valid_cycles"] - target) > target // 100):
            failures.append("lane %d failed status/errors/losses/exposure validation" % lane)
    require(not failures, site + ": " + "; ".join(failures))


def collect_results(boxes, selections, starts, masks, duration, seconds):
    failures = []
    for site in ("F1", "F2"):
        if selections[site]:
            seq, run = starts[site]
            try:
                wait_response(site, boxes[site], seq + 1, seconds + 40)
                validate_records(site, boxes[site], masks[site], run + 1, duration)
            except Exception as error:
                failures.append(site + ": " + str(error))
    require(not failures, "; ".join(failures))


def run_test(registry, boxes, selections, seconds, acknowledge, expected):
    duration = validate_duration(seconds)
    starts, configs, masks = {}, {}, {}
    for site in ("F1", "F2"):
        starts[site] = predecessor(site, boxes[site], expected.get(site))
        configs[site] = configuration(site, boxes[site])
        cfg = configs[site]
        require((cfg[6] & 7) == 2 and cfg[7] == 0 and cfg[6] & 0x100 and cfg[1:3] == cfg[3:5], site + " configuration not applied")
        require(selections[site] & ~cfg[2] == 0, site + " receive selection includes disabled quads")
        masks[site] = receive_words(site, selections[site])
        require(not cfg[1] & 0x3fff or acknowledge, "FireFly TX acknowledgement required")
        check_clocks(site, boxes[site], cfg[1] | cfg[2])
    require(any(selections.values()), "select at least one receive quad")
    telemetry_snapshot(registry, "pre")
    owned = {}
    try:
        for site in ("F1", "F2"):
            seq, run = starts[site]
            # Recheck immediately before the first possible write.
            predecessor(site, boxes[site], (seq, run))
            require(configuration(site, boxes[site]) == configs[site], site + " configuration changed")
            if configs[site][1]:
                owned[site] = seq + 1  # Include uncertain start submissions in cleanup.
                seq = submit(site, boxes[site], seq, 2, duration + 60000, ALL_MASK)
                require(wait_response(site, boxes[site], seq, 5) == 0, site + " session start failed")
            starts[site] = (seq, run)
        for site in ("F1", "F2"):
            if selections[site]:
                seq, run = starts[site]
                submit(site, boxes[site], seq, 0x10501, duration, masks[site])
        deadline = time.monotonic() + 30
        while True:
            active = [boxes[s].read_u32(0xc8) for s in ("F1", "F2") if selections[s]]
            if all(state & 15 == 2 for state in active):
                break
            require(time.monotonic() < deadline, "RUN not observed; no retry")
            time.sleep(.01)
        started = time.monotonic()
        for fraction, phase in ((1.0 / 3, "one-third"), (2.0 / 3, "two-thirds")):
            while time.monotonic() < started + seconds * fraction:
                time.sleep(min(.5, max(0, started + seconds * fraction - time.monotonic())))
            telemetry_snapshot(registry, phase)
        collect_results(boxes, selections, starts, masks, duration, seconds)
    finally:
        failures = []
        for site in owned:
            box = boxes[site]
            try:
                state = box.read_u32(0xc8)
                if state & SESSION_ACTIVE:
                    require(state & 0x1ffff == 0, site + " not idle for safe session stop")
                    seq = box.read_u32(0xa0)
                    require(box.read_u32(0xf0) == seq, site + " request still pending")
                    stop = submit(site, box, seq, 3, 0, ALL_MASK)
                    require(wait_response(site, box, stop, 5) == 0, site + " stop failed")
                require(box.read_u32(0xc8) == CAPABILITY, site + " unhealthy after stop")
            except Exception as error:
                failures.append(str(error))
        try:
            telemetry_snapshot(registry, "post")
        except Exception as error:
            failures.append("post telemetry: " + str(error))
        require(not failures, "cleanup/post telemetry failed: " + "; ".join(failures))
    for site in ("F1", "F2"):
        require(configuration(site, boxes[site]) == configs[site], site + " configuration changed during run")
        require(boxes[site].read_u32(0xc8) == CAPABILITY, site + " unhealthy final state")
    print("V3_RESULT PASS duration_seconds=%d F1_rx=%07x F2_rx=%07x" %
          (seconds, selections["F1"], selections["F2"]), flush=True)


def preset_masks(stage, f1_quads="q121-q124", f2_quads="q121-q124"):
    if stage == "enable-inter-fpga":
        return {site: quad_mask("q221-q234") for site in ("F1", "F2")}
    masks = {"F1": quad_mask(f1_quads), "F2": quad_mask(f2_quads)}
    for site, mask in masks.items():
        require(mask & ~0x3fff == 0 and bin(mask).count("1") == 4,
                site + " loopback requires exactly four distinct FireFly quads q121-q134")
    return masks


def configure_pair(boxes, masks, expected):
    # Check both endpoints before changing either. Each configure rechecks its
    # predecessor; a failure stops here without retry or automatic rollback.
    starts = {}
    for site in ("F1", "F2"):
        starts[site] = predecessor(site, boxes[site], expected.get(site), allow_fault=True)
        require(configuration(site, boxes[site])[6] & 0x100,
                site + " cleanup or stop acknowledgement still pending")
        check_clocks(site, boxes[site], masks[site])
    for site in ("F1", "F2"):
        print("V3_PRESET site=%s tx=%07x rx=%07x" % (site, masks[site], masks[site]), flush=True)
        configure(site, boxes[site], masks[site], masks[site], starts[site])
    print("V3_PRESET CONFIGURED sessions_off=1", flush=True)


def validate_runtime(directory=None):
    directory = Path(directory or Path(__file__).resolve().parent)
    manifest = json.loads((directory / "all_links_v3_runtime_manifest.json").read_text())
    require(manifest.get("schema") == 1, "runtime manifest schema mismatch")
    required = {"board_all_links_v3.py", "all_links_v3_contract.py",
                "all_links_v2_timed_common.py", "all_links_v2_timed_contract.py",
                "milestone3_12hour_external_soak.py",
                "enable_all_links_v3_inter_fpga.py", "test_all_links_v3_firefly_loopback.py"}
    require(set(manifest.get("files", {})) == required, "runtime manifest file inventory mismatch")
    for name in sorted(required):
        digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        require(digest == manifest["files"][name], "runtime source hash mismatch: " + name)
        print("V3_RUNTIME_VERIFIED file=%s sha256=%s" % (name, digest), flush=True)


def main(preset=None):
    descriptions = {
        "enable-inter-fpga": "Enable TX/RX q221-q234 on both FPGAs, disabling all FireFly quads. Add --test for a timed bidirectional PRBS31 test.",
        "loopback-four": "Configure and test four physical external FireFly loopback quads per FPGA (default q121-q124). All other quads are disabled. Requires fitted optical self-loops; this is not internal PMA loopback.",
    }
    parser = argparse.ArgumentParser(description=descriptions.get(preset, __doc__))
    if preset:
        parser.set_defaults(stage=preset)
    else:
        parser.add_argument("stage", choices=("status", "configure", "run", "enable-inter-fpga", "loopback-four"))
    generic_help = argparse.SUPPRESS if preset else None
    parser.add_argument("--site", choices=("F1", "F2"), help=generic_help)
    parser.add_argument("--tx", help=generic_help); parser.add_argument("--rx", help=generic_help)
    parser.add_argument("--f1-rx", default="none", help=generic_help)
    parser.add_argument("--f2-rx", default="none", help=generic_help)
    parser.add_argument("--duration-seconds", type=int, default=90)
    parser.add_argument("--acknowledge-firefly-tx", action="store_true")
    parser.add_argument("--test", action="store_true",
                        help="also run a timed test after enable-inter-fpga (default: configure only)")
    parser.add_argument("--configure-only", action="store_true",
                        help="configure loopback-four without starting PRBS sessions or measurement")
    parser.add_argument("--f1-quads", default="q121-q124", help="four external FireFly loopback quads on F1")
    parser.add_argument("--f2-quads", default="q121-q124", help="four external FireFly loopback quads on F2")
    for site in ("f1", "f2"):
        parser.add_argument("--" + site + "-sequence", type=int)
        parser.add_argument("--" + site + "-run", type=int)
    args = parser.parse_args()
    is_preset = args.stage in ("enable-inter-fpga", "loopback-four")
    require(not args.test or args.stage == "enable-inter-fpga", "--test is for enable-inter-fpga")
    require(not args.configure_only or args.stage == "loopback-four", "--configure-only is for loopback-four")
    require(args.stage == "loopback-four" or args.f1_quads == args.f2_quads == "q121-q124",
            "--f1-quads/--f2-quads are for loopback-four")
    if is_preset:
        require(args.site is None and args.tx is None and args.rx is None and
                args.f1_rx == args.f2_rx == "none", "preset controls both sites and their complete TX/RX masks")
        masks = preset_masks(args.stage, args.f1_quads, args.f2_quads)
        require(args.stage != "loopback-four" or args.acknowledge_firefly_tx,
                "FireFly TX acknowledgement required; physical external loopbacks must be fitted")
        validate_duration(args.duration_seconds)
    if args.stage == "configure":
        require(args.site and args.tx is not None and args.rx is not None,
                "configure requires --site --tx --rx")
        tx = quad_mask(args.tx); quad_mask(args.rx)
        require(not tx & 0x3fff or args.acknowledge_firefly_tx,
                "FireFly TX acknowledgement required when enabling outward serializers")
    if args.stage == "run":
        require(args.site is None, "run uses --f1-rx/--f2-rx rather than --site")
        require(quad_mask(args.f1_rx) | quad_mask(args.f2_rx), "select at least one receive quad")
        validate_duration(args.duration_seconds)
    if args.stage != "status":
        require_release()  # Always before registry construction or any MCU access.
    validate_runtime()
    runtime = Path(__file__).resolve().parent / "cm_interface"
    commit = subprocess.check_output(["git", "-C", str(runtime), "rev-parse", "HEAD"]).decode().strip()
    tag = subprocess.check_output(["git", "-C", str(runtime), "describe", "--tags", "--exact-match"]).decode().strip()
    clean = subprocess.check_output(["git", "-C", str(runtime), "status", "--porcelain"])
    require(commit == CM_COMMIT and tag == "v1.0.3" and not clean, "clean cm_interface v1.0.3 required")
    expected = {}
    for site in ("F1", "F2"):
        seq, run = getattr(args, site.lower() + "_sequence"), getattr(args, site.lower() + "_run")
        require((seq is None) == (run is None), "supply both sequence/run guards for each guarded site")
        if seq is not None:
            expected[site] = (seq, run)
    lock = acquire_lock()  # Share the existing cross-version software lock.
    try:
        registry = load_registry()
        boxes = make_boxes(registry)
        if is_preset:
            configure_pair(boxes, masks, expected)
            if args.test or (args.stage == "loopback-four" and not args.configure_only):
                # Configuration consumed one sequence per site; rediscover the
                # new predecessors under the same software lock before testing.
                run_test(registry, boxes, masks, args.duration_seconds, args.acknowledge_firefly_tx, {})
        elif args.stage == "configure":
            require(args.site and args.tx is not None and args.rx is not None,
                    "configure requires --site --tx --rx")
            configure(args.site, boxes[args.site], quad_mask(args.tx), quad_mask(args.rx), expected.get(args.site))
        elif args.stage == "run":
            run_test(registry, boxes, {"F1": quad_mask(args.f1_rx), "F2": quad_mask(args.f2_rx)},
                     args.duration_seconds, args.acknowledge_firefly_tx, expected)
        else:
            for site, box in boxes.items():
                if args.site and site != args.site:
                    continue
                require(box.read_u32(0xc0) == box.read_u32(0xc4) == VERSION, site + " v3 identity mismatch")
                cfg = configuration(site, box)
                for q in range(28):
                    box.write_u32(0xcc, 0x80 + q)
                    words = tuple(box.read_u32(a) for a in range(0xd0, 0xf0, 4))
                    require(words[0] >> 16 == 0x5153 and words[0] & 63 == q,
                            site + " raw quad diagnostic schema/index mismatch")
                    print("V3_RAW_QUAD site=%s index=%d words=%r" % (site, q, words), flush=True)
                check_clocks(site, box, cfg[1] | cfg[2])
            telemetry_snapshot(registry, "status")
    finally:
        os.close(lock)
    return 0


class Tee:
    def __init__(self, terminal, log):
        self.terminal, self.log = terminal, log
    def write(self, text):
        self.terminal.write(text); self.log.write(text)
    def flush(self):
        self.terminal.flush(); self.log.flush()


def recorded_main(preset=None):
    directory = Path("logs")
    directory.mkdir(exist_ok=True)
    stem = directory / ("all-links-v3-%d" % int(time.time() * 1000000))
    path = stem.with_suffix(".log")
    code = 1
    with path.open("x") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)), contextlib.redirect_stderr(Tee(sys.stderr, log)):
        print("V3_PROVENANCE version=%#x bit=%s dcp=%s elf=%s cm=%s" %
              (VERSION, BIT_SHA256, DCP_SHA256, ELF_SHA256, CM_COMMIT), flush=True)
        for module in tuple(sys.modules.values()):
            filename = getattr(module, "__file__", None)
            if filename:
                source = Path(filename).resolve()
                if source.parent == Path(__file__).resolve().parent and source.suffix == ".py":
                    print("V3_SOURCE_SHA256 file=%s sha256=%s" %
                          (source.name, hashlib.sha256(source.read_bytes()).hexdigest()), flush=True)
        try:
            code = main(preset)
        except SystemExit as error:
            code = error.code if isinstance(error.code, int) else 1
        except Exception:
            traceback.print_exc()
        print("V3_EXIT code=%d" % code, flush=True)
    raw = path.read_bytes()
    with stem.with_suffix(".report.md").open("x") as report:
        report.write("# All-links v3 process report\n\nExit code: %d\n\nLog: `%s`\n\nSHA-256: `%s`\n\n" %
                     (code, path, hashlib.sha256(raw).hexdigest()))
        lines = raw.decode().splitlines()
        report.write("```text\n" + "\n".join(line for line in lines if line.startswith(
            ("V3_PROVENANCE", "V3_SOURCE_SHA256", "V3_RUNTIME_VERIFIED", "V3_PRESET", "V3_RAW_QUAD", "V3_CONFIG", "V3_RESULT", "PREDECESSOR", "CLOCK", "RECORD", "POWER12V", "FPGA", "LGA", "FIREFLY"))) + "\n```\n")
        if code:
            report.write("\nFailure tail:\n\n```text\n" + "\n".join(lines[-30:]) + "\n```\n")
    return code


if __name__ == "__main__":
    raise SystemExit(recorded_main())
