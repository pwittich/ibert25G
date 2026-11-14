#!/usr/bin/env python3
"""Separate-image eye scans and offline plots. No programming/reset/retry."""
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

import eye_scan_v1_contract as contract
from eye_scan_data import SCHEMA, QUADS, descriptor, decode_point, write_csv, plot
from all_links_v3_contract import quad_mask, required_refclks, UNFITTED
from all_links_v2_timed_common import (acquire_lock, load_registry, make_boxes,
                                     CLOCK_NAMES, telemetry_snapshot, require, wait_response)
from all_links_v2_timed_contract import ALL_MASK, CAPABILITY, SESSION_ACTIVE, SESSION_READY


def validate_runtime(directory=None):
    directory = Path(directory or Path(__file__).resolve().parent)
    manifest = json.loads((directory / "eye_scan_v1_runtime_manifest.json").read_text())
    require(manifest.get("schema") == 1 and manifest.get("version") == contract.VERSION,
            "eye runtime manifest schema/version mismatch")
    require(set(manifest.get("files", {})) == set(contract.RUNTIME_FILES), "runtime inventory mismatch")
    for name in contract.RUNTIME_FILES:
        digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        require(digest == manifest["files"][name], "runtime source changed: " + name)
        print("EYE_SOURCE file=%s sha256=%s" % (name, digest), flush=True)
    library = directory / "cm_interface"
    def git(*args):
        return subprocess.check_output(["git", "-C", str(library)] + list(args)).decode().strip()
    require(git("rev-parse", "HEAD") == contract.CM_COMMIT and
            git("describe", "--exact-match", "--tags") == "v1.0.3" and
            not git("status", "--porcelain"), "clean pinned cm_interface v1.0.3 required")


def identity(site, box, idle=False, ready=True):
    values = tuple(box.read_u32(a) for a in (0xc0, 0xc4, 0xc8, 0xa0, 0xf0, 0xf8))
    second = tuple(box.read_u32(a) for a in (0xc0, 0xc4, 0xc8, 0xa0, 0xf0, 0xf8))
    if ready:
        require(values == second, site + " identity/publication changed")
    fw, hw, state, seq, ack, run = second
    require(fw == hw == contract.VERSION, site + " requires eye-scan v1/0x00020503")
    if ready:
        require(seq == ack, site + " request pending")
    if idle:
        require(state == CAPABILITY, site + " requires healthy IDLE/session-off")
    return dict(fw=fw, hw=hw, state=state, sequence=seq, acknowledgement=ack, run=run,
                stable=values == second)


def page_words(box, selector):
    box.write_u32(0xcc, selector)
    return tuple(box.read_u32(a) for a in range(0xd0, 0xf0, 4))


def progress(site, box):
    words = page_words(box, 0xf6)
    require(words[0] == 0x45595001, site + " eye progress schema mismatch")
    value = dict(job=words[1], status=words[2], busy=bool(words[2] & 1),
                 available=bool(words[2] & 2), fatal=bool(words[2] & 4),
                 reason=words[2] >> 16, count=words[3], remaining_ms=words[6], raw=list(words))
    require(value["count"] <= 4096, site + " impossible point count")
    print("EYE_PROGRESS site=%s data=%s" % (site, json.dumps(value, sort_keys=True)), flush=True)
    return value


def configuration(site, box):
    words = page_words(box, 0xf7)
    require(words[0] == 0x51430001, site + " config schema mismatch")
    require(words[1:3] == words[3:5] and (words[6] & 7) == 2 and words[7] == 0,
            site + " configuration not applied")
    print("EYE_CONFIG site=%s words=%r" % (site, words), flush=True)
    return words


def check_clocks(site, box, enabled):
    require(box.read_u32(0x9c) == 0x434da501, site + " clock ABI/valid status mismatch")
    values = {}
    for index, name in enumerate(CLOCK_NAMES):
        address = (index + 2) * 4
        values[address] = box.read_u32(address)
        print("CLOCK site=%s name=%s khz=%d" % (site, name, values[address]), flush=True)
    for address, nominal in ((8, 200000), (0x24, 100000), (0x28, 325000)):
        require(abs(values[address] - nominal) < nominal * .001, site + " fabric clock out of range")
    for address in required_refclks(enabled):
        require(abs(values[address] - 322266) < 323, site + " required GT clock out of range")
    require(box.read_u32(0x9c) == 0x434da501, site + " clock publication changed")
    return values


def sequence_ordinal(sequence):
    """Invert reflected Gray code; every successor changes exactly one bit."""
    ordinal = sequence
    shift = sequence >> 1
    while shift:
        ordinal ^= shift
        shift >>= 1
    return ordinal


def next_sequence(sequence):
    ordinal = sequence_ordinal(sequence)
    require(ordinal < 0xffffffff, "eye command sequence exhausted")
    ordinal += 1
    return ordinal ^ (ordinal >> 1)


def issue(site, box, command, duration=0, timeout=0, operands=(0, 0, 0, 0)):
    before = identity(site, box)
    require(before["state"] & 15 == 0, site + " BER engine busy")
    for address, value in ((0xa4, command), (0xa8, duration), (0xac, timeout)) + tuple(
            (0xb0 + 4 * i, word) for i, word in enumerate(operands)):
        box.write_u32(address, value)
        require(box.read_u32(address) == value, site + " request staging/readback mismatch")
    seq = next_sequence(before["sequence"])
    print("EYE_COMMAND site=%s sequence=%d command=%d operands=%r" % (site, seq, command, operands), flush=True)
    changed = before["sequence"] ^ seq
    byte = (changed.bit_length() - 1) // 8
    box.write_u8(0xa0 + byte, (seq >> (byte * 8)) & 255)
    require(wait_response(site, box, seq, 5) == 0, site + " command rejected; no retry")
    require(box.read_u32(0xf8) == before["run"], site + " scan/session command changed BER run ID")
    return seq


def fetch(site, box, job, global_lane, result=None):
    before = progress(site, box)
    require(before["job"] == job and not before["busy"], site + " scan not frozen for retrieval")
    if result is None:
        result = []
    for index in range(before["count"]):
        issue(site, box, 7, operands=(index, job, 0, 0))
        raw = tuple(box.read_u32(a) for a in range(0xd0, 0xf0, 4))
        record = decode_point(raw, job, global_lane)
        result.append(record)
        print("EYE_POINT site=%s index=%d raw=%s" % (site, index, " ".join("%08x" % w for w in raw)), flush=True)
    after = progress(site, box)
    require(after["job"] == job and after["count"] == before["count"] and not after["busy"],
            site + " matrix changed during retrieval")
    return result


def run_scan(args, registry, boxes, request, prefix):
    initial, configs, clocks, eye_states = {}, {}, {}, {}
    for site in ("F1", "F2"):
        initial[site] = identity(site, boxes[site], idle=True)
        eye_states[site] = progress(site, boxes[site])
        require(not eye_states[site]["busy"] and not eye_states[site]["fatal"],
                site + " has an unowned eye job or fatal lock")
        require(sequence_ordinal(initial[site]["sequence"]) < 0xffffffff - len(request["xs"]) * len(request["ys"]) - 20,
                site + " insufficient sequence space for retrieval/cleanup")
        cfg = configs[site] = configuration(site, boxes[site])
        require(not cfg[1] & 0x3fff or args.acknowledge_firefly_tx,
                "every enabled outward FireFly transmitter requires acknowledgement")
        clocks[site] = check_clocks(site, boxes[site], cfg[1] | cfg[2])
    receiver, tx_site = args.receiver, args.transmitter
    box = boxes[receiver]
    qindex = QUADS.index(request["quad"])
    require(request["global_lane"] not in UNFITTED[receiver], "requested receiver is unfitted")
    require(configs[receiver][2] & (1 << qindex), "receiver quad is disabled")
    require(configs[tx_site][1] & (1 << QUADS.index(args.tx_quad)), "declared transmitter quad is disabled")
    before = progress(receiver, box)
    require(not before["busy"] and not before["available"] and not before["fatal"],
            "prior eye job must be reviewed/acknowledged before a new scan")
    raw_quad_before = page_words(box, 0x80 + qindex)
    require(raw_quad_before[0] >> 16 == 0x5153 and raw_quad_before[0] & 0x80 and
            not raw_quad_before[0] & 0x40,
            "receiver quad fault before scan")
    document = dict(schema=SCHEMA, synthetic=False, version=contract.VERSION,
        site=receiver, quad=request["quad"], lane=request["lane"], global_lane=request["global_lane"],
        transmitter=dict(site=tx_site, quad=args.tx_quad), requested=request,
        artifacts=dict(bit=contract.BIT_SHA256, dcp=contract.DCP_SHA256, elf=contract.ELF_SHA256),
        cm_commit=contract.CM_COMMIT, initial=initial, configurations=configs,
        clocks=clocks, initial_eye=eye_states, raw_quad_before=raw_quad_before, points=[], errors=[], job=before["job"] + 1)
    owned = []
    launched = False
    interrupted = False
    telemetry_snapshot(registry, "eye-pre")
    try:
        for site in ("F1", "F2"):
            require(configuration(site, boxes[site]) == configs[site], site + " configuration changed")
            if configs[site][1]:
                owned.append(site)  # uncertain submission also receives bounded cleanup
                issue(site, boxes[site], 2, request["budget_ms"] + 60000, operands=ALL_MASK)
        launched = True  # include a possibly accepted but unacknowledged start
        issue(receiver, box, 5, request["budget_ms"], request["point_timeout_cycles"], request["words"])
        started = time.monotonic()
        next_telemetry = 1
        while True:
            current = progress(receiver, box)
            require(current["job"] == document["job"], "scan job identity changed")
            if not current["busy"]:
                break
            elapsed = time.monotonic() - started
            require(elapsed < request["budget_ms"] / 1000.0 + 15, "scan deadline exceeded")
            if next_telemetry <= 2 and current["count"] >= len(request["xs"]) * len(request["ys"]) * next_telemetry / 3.0:
                telemetry_snapshot(registry, "eye-during-%d" % next_telemetry)
                next_telemetry += 1
            time.sleep(.25)
    except BaseException as error:
        interrupted = isinstance(error, KeyboardInterrupt)
        document["errors"].append(type(error).__name__ + ": " + str(error))
    finally:
        # Cancel only our expected job; never acknowledge/erase retained data.
        if launched:
            try:
                current = progress(receiver, box)
                if current["job"] == document["job"] and current["busy"]:
                    issue(receiver, box, 6, operands=(document["job"], 0, 0, 0))
                    deadline = time.monotonic() + 12
                    while current["busy"] and time.monotonic() < deadline:
                        time.sleep(.1)
                        current = progress(receiver, box)
                    require(not current["busy"], "bounded scan cleanup did not finish")
                document["final_progress"] = current
            except Exception as error:
                document["errors"].append("scan cleanup: " + str(error))
        for site in owned:
            try:
                state = boxes[site].read_u32(0xc8)
                if state & (SESSION_ACTIVE | SESSION_READY):
                    issue(site, boxes[site], 3, operands=ALL_MASK)
                require(not boxes[site].read_u32(0xc8) & (SESSION_ACTIVE | SESSION_READY),
                        site + " session not confirmed off")
            except Exception as error:
                document["errors"].append(site + " TX stop: " + str(error))
        for site in ("F1", "F2"):
            try:
                document.setdefault("final", {})[site] = identity(site, boxes[site])
                require(document["final"][site]["state"] == CAPABILITY,
                        site + " requires healthy final IDLE/session-off")
                cfg = configuration(site, boxes[site])
                require(cfg == configs[site], site + " configuration changed during scan")
                check_clocks(site, boxes[site], cfg[1] | cfg[2])
            except Exception as error:
                document["errors"].append(site + " final status: " + str(error))
        try:
            telemetry_snapshot(registry, "eye-post")
            document["raw_quad_after"] = page_words(box, 0x80 + qindex)
            require(document["raw_quad_after"][0] >> 16 == 0x5153 and
                    document["raw_quad_after"][0] & 0x80 and
                    not document["raw_quad_after"][0] & 0x40,
                    "receiver quad unhealthy after scan")
            current = progress(receiver, box)
            document["final_progress"] = current
            if current["job"] == document["job"] and not current["busy"]:
                fetch(receiver, box, document["job"], request["global_lane"], document["points"])
        except Exception as error:
            document["errors"].append("result retrieval: " + str(error))
        expected = [(x, y) for y in request["ys"] for x in request["xs"]]
        actual = [(p["horizontal"], p["vertical"]) for p in document["points"]]
        final = document.get("final_progress", {})
        if actual != expected or not all(p["complete"] for p in document["points"]) or final.get("reason") or final.get("fatal"):
            document["errors"].append("scan matrix incomplete or contains a failed point/job")
        with Path(str(prefix) + ".json").open("x") as handle:
            json.dump(document, handle, indent=2, sort_keys=True)
            handle.write("\n")
        write_csv(str(prefix) + ".csv", document["points"])
    require(not document["errors"], "; ".join(document["errors"]))
    require(not interrupted, "scan interrupted")
    print("EYE_SAVED prefix=%s job=%d points=%d results_retained=1" %
          (prefix, document["job"], len(document["points"])), flush=True)


def main(argv=None, prefix=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command")
    plotting = sub.add_parser("plot")
    plotting.add_argument("input"); plotting.add_argument("--output-prefix", required=True)
    status = sub.add_parser("status"); status.add_argument("--site", choices=("F1", "F2"))
    config = sub.add_parser("configure")
    config.add_argument("--site", choices=("F1", "F2"), required=True)
    config.add_argument("--tx", required=True); config.add_argument("--rx", required=True)
    config.add_argument("--acknowledge-firefly-tx", action="store_true")
    scan = sub.add_parser("scan")
    scan.add_argument("--receiver", choices=("F1", "F2"), required=True)
    scan.add_argument("--quad", type=lambda x: int(x.lower().lstrip("q")), choices=QUADS, required=True)
    scan.add_argument("--lane", type=int, choices=range(4), required=True)
    scan.add_argument("--transmitter", choices=("F1", "F2"), required=True)
    scan.add_argument("--tx-quad", type=lambda x: int(x.lower().lstrip("q")), choices=QUADS, required=True)
    scan.add_argument("--horizontal", default="-32:32:2")
    scan.add_argument("--vertical", default="-120:120:8")
    scan.add_argument("--prescale", type=int, default=5)
    scan.add_argument("--budget-seconds", type=int, default=120)
    scan.add_argument("--point-timeout-ms", type=int, default=1000)
    scan.add_argument("--acknowledge-firefly-tx", action="store_true")
    for action in ("cancel", "ack"):
        p = sub.add_parser(action)
        p.add_argument("--site", choices=("F1", "F2"), required=True)
        p.add_argument("--job", type=int, required=True)
    args = parser.parse_args(argv)
    require(args.command is not None, "select an operation")
    if args.command == "plot":
        plot(json.loads(Path(args.input).read_text()), args.output_prefix)
        return 0
    request = None
    if args.command == "scan":
        request = descriptor(args.quad, args.lane, args.horizontal, args.vertical,
                             args.prescale, args.budget_seconds * 1000, args.point_timeout_ms)
    if args.command != "status":
        contract.require_release()  # before manifest/library checks or MCU construction
    validate_runtime()
    lock = acquire_lock()
    try:
        registry = load_registry(); boxes = make_boxes(registry)
        if args.command == "status":
            for site in ("F1", "F2"):
                if not args.site or args.site == site:
                    print("EYE_IDENTITY site=%s data=%r" % (site, identity(site, boxes[site], ready=False)), flush=True)
                    progress(site, boxes[site]); configuration(site, boxes[site])
            telemetry_snapshot(registry, "eye-status")
        elif args.command == "configure":
            box = boxes[args.site]; identity(args.site, box, idle=True)
            current = progress(args.site, box)
            require(not current["busy"] and not current["fatal"], "eye engine locked")
            tx, rx = quad_mask(args.tx), quad_mask(args.rx)
            require(not tx & 0x3fff or args.acknowledge_firefly_tx, "FireFly acknowledgement required")
            before = page_words(box, 0xf7)
            require(before[0] == 0x51430001 and before[6] & 0x100, "configuration not eligible")
            check_clocks(args.site, box, tx | rx)
            issue(args.site, box, 4, operands=(tx, rx, 0, 0))
            after = configuration(args.site, box)
            require(after[1:5] == (tx, rx, tx, rx) and after[5] == (before[5] + 1) & 0xffffffff,
                    "configuration application mismatch")
        elif args.command in ("cancel", "ack"):
            current = progress(args.site, boxes[args.site])
            require(current["job"] == args.job, "explicit job predecessor mismatch")
            issue(args.site, boxes[args.site], 6 if args.command == "cancel" else 8,
                  operands=(args.job, 0, 0, 0))
            progress(args.site, boxes[args.site])
        else:
            require(prefix is not None, "scan requires recorded execution")
            run_scan(args, registry, boxes, request, prefix)
    finally:
        os.close(lock)
    return 0


class Tee:
    def __init__(self, terminal, log):
        self.terminal, self.log = terminal, log
    def write(self, value):
        self.terminal.write(value); self.log.write(value)
    def flush(self):
        self.terminal.flush(); self.log.flush()


def recorded_main():
    root = Path("logs"); root.mkdir(exist_ok=True)
    prefix = root / ("eye-scan-v1-%d" % int(time.time() * 1000000))
    path = Path(str(prefix) + ".log")
    code = 1
    with path.open("x") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)), contextlib.redirect_stderr(Tee(sys.stderr, log)):
        print("EYE_PROVENANCE version=%#x bit=%s dcp=%s elf=%s cm=%s" %
              (contract.VERSION, contract.BIT_SHA256, contract.DCP_SHA256, contract.ELF_SHA256, contract.CM_COMMIT), flush=True)
        try:
            code = main(prefix=prefix)
        except SystemExit as error:
            code = error.code if isinstance(error.code, int) else 1
        except BaseException:
            traceback.print_exc()
        print("EYE_EXIT code=%d" % code, flush=True)
    raw = path.read_bytes()
    with Path(str(prefix) + ".report.md").open("x") as report:
        report.write("# Eye-scan v1 process report\n\nExit code: %d\n\nLog SHA-256: `%s`\n\n" %
                     (code, hashlib.sha256(raw).hexdigest()))
        for suffix in ("json", "csv"):
            artifact = Path(str(prefix) + "." + suffix)
            if artifact.is_file():
                report.write("- `%s`: `%s`\n" % (artifact, hashlib.sha256(artifact.read_bytes()).hexdigest()))
        lines = raw.decode().splitlines()
        report.write("\n```text\n" + "\n".join(line for line in lines if line.startswith(
            ("EYE_PROVENANCE", "EYE_CONFIG", "EYE_PROGRESS", "EYE_SAVED", "EYE_EXIT"))) + "\n```\n")
        if code:
            report.write("\nFailure tail:\n\n```text\n" + "\n".join(lines[-30:]) + "\n```\n")
    return code


if __name__ == "__main__":
    raise SystemExit(recorded_main())
