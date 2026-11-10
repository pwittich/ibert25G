#!/usr/bin/env python3
"""Shared protocol, validation and telemetry for all-links-v2 timed tests."""
import math
import os
import sys
import time

from all_links_v2_timed_contract import (
    ALL_MASK, CAPABILITY, DIRECT_MASKS, REFCLK_ADDRESSES, SESSION_ACTIVE,
    SESSION_READY, VERSION, expected_cycles, mask_lanes, validate_duration)
from milestone3_12hour_external_soak import FpgaMailbox, read_lane

LOCK_PATH = "/tmp/all-links-v2-90s-mcu.lock"
CLOCK_NAMES = (
    "clk_200_ext", "lhc_clk", "tcds40_clk", "rt_x4_r0_clk",
    "rt_x12_r0_clk", "lf_x4_r0_clk", "lf_x12_r0_clk", "clk_100",
    "clk_325", "rt_r0_p", "rt_r0_n", "rt_r0_l", "rt_r0_i", "rt_r0_g",
    "rt_r0_e", "rt_r0_b", "lf_r0_y", "lf_r0_w", "lf_r0_u", "lf_r0_r",
    "lf_r0_af", "lf_r0_ad", "lf_r0_ab", "rt_r1_p", "rt_r1_n",
    "rt_r1_l", "rt_r1_i", "rt_r1_g", "rt_r1_e", "rt_r1_b", "lf_r1_y",
    "lf_r1_w", "lf_r1_u", "lf_r1_r", "lf_r1_af", "lf_r1_ad", "lf_r1_ab")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def words_for_lanes(lanes):
    words = [0, 0, 0, 0]
    for lane in lanes:
        words[lane // 32] |= 1 << (lane % 32)
    return tuple(words)


def parse_quads(spec):
    """Parse comma-separated qNNN or inclusive qNNN-qMMM selections."""
    selected = set()
    for item in spec.split(","):
        item = item.strip().lower().replace("q", "")
        if not item:
            raise ValueError("empty quad selector")
        bounds = item.split("-")
        if len(bounds) == 1:
            first = last = int(bounds[0])
        elif len(bounds) == 2:
            first, last = (int(value) for value in bounds)
        else:
            raise ValueError("invalid quad selector: " + item)
        if first > last or first < 121 or last > 134:
            raise ValueError("quad selection must be within q121-q134")
        selected.update(range(first, last + 1))
    return tuple(sorted(selected))


def firefly_mask(quads):
    lanes = []
    for quad in quads:
        base = (quad - 121) * 4
        lanes.extend(range(base, base + 4))
    return words_for_lanes(lanes)


def acquire_lock():
    import fcntl
    descriptor = os.open(LOCK_PATH, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        os.close(descriptor)
        raise RuntimeError("another serialized MCU owner is active")
    return descriptor


def load_registry():
    # Deployment copies the authoritative int_test checkout beside this file.
    # Apollo does not mount its original NFS path, so never fall back to the
    # older /home/cms/25G copy.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from cm_interface.registry import Registry
    return Registry(setup="tf", dev_path="/dev/ttyUL4")


def check_clocks(site, box):
    require(box.read_u32(0x9c) == 0x434da501,
            site + " clock-monitor ABI/valid status mismatch")
    values = {}
    for index, name in enumerate(CLOCK_NAMES):
        address = (index + 2) * 4
        value = box.read_u32(address)
        values[address] = value
        print("CLOCK site=%s r=%02d name=%s khz=%d" %
              (site, index + 2, name, value), flush=True)
    for address, nominal in ((0x08, 200000), (0x24, 100000), (0x28, 325000)):
        require(abs(values[address] - nominal) < nominal * .001,
                "%s clock %#x invalid: %d kHz" % (site, address, values[address]))
    for address in REFCLK_ADDRESSES:
        require(abs(values[address] - 322266) < 323,
                "%s GT REFCLK %#x invalid: %d kHz" %
                (site, address, values[address]))
    require(box.read_u32(0x9c) == 0x434da501,
            site + " clock publication changed while reading")


def check_ready(site, box, sequence, run):
    require(box.read_u32(0xc0) == VERSION and box.read_u32(0xc4) == VERSION,
            site + " all-links-v2 identity mismatch")
    require(box.read_u32(0xc8) == CAPABILITY,
            site + " is not healthy IDLE with TX session off")
    require((box.read_u32(0xa0), box.read_u32(0xf0), box.read_u32(0xf8)) ==
            (sequence, sequence, run), site + " predecessor sequence/run mismatch")
    check_clocks(site, box)
    box.write_u32(0xcc, 0xfe)
    require(box.read_u32(0xd0) == 0x40 and box.read_u32(0xec) == 0,
            site + " platform diagnostic is not healthy")


def resolve_predecessors(boxes, expected=None):
    """Read stable idle state while the caller owns the MCU lock; never write."""
    predecessors = {}
    addresses = (0xc0, 0xc4, 0xc8, 0xa0, 0xf0, 0xf8)
    for site in ("F1", "F2"):
        box = boxes[site]
        first = tuple(box.read_u32(address) for address in addresses)
        second = tuple(box.read_u32(address) for address in addresses)
        require(first == second, site + " state changed while reading predecessor; no request issued")
        fw, hw, state, sequence, response, run = second
        require(fw == VERSION and hw == VERSION,
                site + " all-links-v2 identity mismatch")
        require(state == CAPABILITY,
                site + " is not healthy IDLE with TX session off")
        require(sequence == response, site + " request/response sequence mismatch")
        require(sequence <= 0xfffffffc and run < 0xffffffff,
                site + " sequence/run exhausted; no request issued")
        predecessors[site] = (sequence, run)
        if expected is not None:
            require(predecessors[site] == expected[site],
                    site + " predecessor sequence/run mismatch")
    for site in ("F1", "F2"):
        sequence, run = predecessors[site]
        print("PREDECESSOR site=%s sequence=%d run=%d mode=%s" %
              (site, sequence, run, "explicit" if expected is not None else "auto"),
              flush=True)
    return predecessors


def submit(site, box, previous, sequence, command, duration_ms, mask):
    require(box.read_u32(0xa0) == previous and box.read_u32(0xf0) == previous,
            site + " sequence changed before submit")
    require(box.read_u32(0xc8) & 0x1ffff == 0, site + " busy/fault before submit")
    fields = ((0xa4, command), (0xa8, duration_ms), (0xac, 0),
              (0xb0, mask[0]), (0xb4, mask[1]), (0xb8, mask[2]), (0xbc, mask[3]))
    for address, value in fields:
        box.write_u32(address, value)
        require(box.read_u32(address) == value, site + " descriptor readback mismatch")
    print("SUBMIT site=%s previous=%d sequence=%d command=%#x duration_ms=%d mask=%s" %
          (site, previous, sequence, command, duration_ms,
           ":".join("%08x" % word for word in mask)), flush=True)
    box.write_u32(0xa0, sequence)  # Sole doorbell; never replay automatically.


def wait_response(site, box, sequence, timeout):
    deadline = time.monotonic() + timeout
    while box.read_u32(0xf0) != sequence:
        require(time.monotonic() < deadline,
                site + " response timeout; preserve evidence and do not retry")
        time.sleep(.1)
    return box.read_u32(0xf4)


def validate_records(site, box, mask, expected_run, duration_ms):
    lanes = mask_lanes(mask)
    expected_summary = (len(lanes) << 16) | (len(lanes) << 8) | 1
    require(box.read_u32(0xf4) == expected_summary and
            box.read_u32(0xfc) == expected_summary and
            box.read_u32(0xf8) == expected_run,
            site + " response summary/run mismatch")
    target_cycles = expected_cycles(duration_ms)
    tolerance = target_cycles // 100
    for lane in lanes:
        record = read_lane(box, lane)
        print("RECORD site=%s run=%d lane=%d data=%r" %
              (site, expected_run, lane, record), flush=True)
        require(record["id_status"] == 0x1800 + lane,
                "%s lane %d not selected+locked" % (site, lane))
        require(record["errors"] == 0 and record["lock_losses"] == 0,
                "%s lane %d has PRBS errors or native lock losses" % (site, lane))
        require(record["tested_bits"] == record["valid_cycles"] * 80,
                "%s lane %d denominator mismatch" % (site, lane))
        require(abs(record["valid_cycles"] - target_cycles) <= tolerance,
                "%s lane %d duration outside one percent" % (site, lane))


def _physical_fireflies(registry):
    # The authoritative TF preset contains exactly the populated modules;
    # absent slots must not be invented or probed.
    return tuple(sorted(registry.fireflies.items()))


def _adc_readings(snapshot):
    """Return readings across native dataclass and Python-3.6 compat builds.

    The installed compat class inherits a namedtuple but overrides
    ``__getitem__`` for name lookup.  Its generated ``readings`` property then
    recursively calls that override.  Bypass only that broken generated
    accessor; the MCU transaction itself has already completed normally.
    """
    try:
        return snapshot.readings
    except RecursionError:
        if isinstance(snapshot, tuple):
            return tuple.__getitem__(snapshot, 0)
        raise


def telemetry_snapshot(registry, label):
    print("TELEMETRY_BEGIN label=%s monotonic=%.6f" % (label, time.monotonic()), flush=True)
    adc = registry.mcu.read_adc()
    readings = _adc_readings(adc)
    by_name = dict((reading.name, reading) for reading in readings)
    voltage = by_name["VCC_12V"].value
    current = by_name["CUR_V_12V"].value
    require(by_name["VCC_12V"].valid and by_name["CUR_V_12V"].valid and
            math.isfinite(voltage) and math.isfinite(current),
            "12 V ADC voltage/current invalid")
    print("POWER12V label=%s volts=%.6f amps=%.6f watts=%.6f" %
          (label, voltage, current, voltage * current), flush=True)
    for reading in readings:
        print("ADC label=%s index=%d name=%s value=%s" %
              (label, reading.index, reading.name, reading.value), flush=True)
    for name in ("F1_TEMP", "F2_TEMP"):
        reading = by_name[name]
        require(reading.valid and math.isfinite(reading.value),
                name + " FPGA diode temperature is invalid")
        print("FPGA_DIODE_TEMP label=%s sensor=%s celsius=%.6f" %
              (label, name, reading.value), flush=True)
    for name in sorted(registry.lga80d):
        device = registry.lga80d[name]
        for page in (0, 1):
            for sensor in (1, 3):
                value = device.read_temperature(page=page, sensor=sensor)
                require(math.isfinite(value), "non-finite LGA80D temperature")
                print("LGA80D_TEMP label=%s device=%s page=%d sensor=%d celsius=%.6f" %
                      (label, name, page, sensor, value), flush=True)
    for name, device in _physical_fireflies(registry):
        value = device.temperature
        require(value is not None and math.isfinite(float(value)),
                name + " FireFly temperature is invalid")
        print("FIREFLY_TEMP label=%s device=%s address=%#x celsius=%s" %
              (label, name, device.address, value), flush=True)
    print("TELEMETRY_END label=%s monotonic=%.6f" % (label, time.monotonic()), flush=True)


def during_telemetry(registry, started, duration_seconds):
    for ordinal, offset in enumerate((duration_seconds / 3.0,
                                      duration_seconds * 2.0 / 3.0), 1):
        remaining = started + offset - time.monotonic()
        if remaining > 0:
            time.sleep(remaining)
        telemetry_snapshot(registry, "during_%d_of_2" % ordinal)


def make_boxes(registry):
    return dict((site, FpgaMailbox(registry.fpgas[site])) for site in ("F1", "F2"))


def print_status(registry, boxes):
    """Read-only identity, mailbox, clocks, and one complete telemetry set."""
    for site in ("F1", "F2"):
        box = boxes[site]
        print("STATUS site=%s fw=%#010x hw=%#010x state=%#010x request=%d response=%d code=%#010x run=%d summary=%#010x" %
              (site, box.read_u32(0xc0), box.read_u32(0xc4),
               box.read_u32(0xc8), box.read_u32(0xa0), box.read_u32(0xf0),
               box.read_u32(0xf4), box.read_u32(0xf8), box.read_u32(0xfc)),
              flush=True)
        require(box.read_u32(0xc0) == VERSION and box.read_u32(0xc4) == VERSION,
                site + " all-links-v2 identity mismatch")
        check_clocks(site, box)
    telemetry_snapshot(registry, "status")


def run_firefly(registry, boxes, quads, predecessors, duration_seconds):
    mask = firefly_mask(quads)
    _run_external(registry, boxes, {"F1": mask, "F2": mask}, predecessors,
                  duration_seconds)
    print("PASS FIREFLY_EXTERNAL_LOOPBACK duration_seconds=%d quads=%s lanes_per_endpoint=%d errors=0" %
          (duration_seconds, ",".join("q%d" % q for q in quads),
           len(mask_lanes(mask))),
          flush=True)


def run_inter_fpga(registry, boxes, predecessors, duration_seconds):
    _run_external(registry, boxes, DIRECT_MASKS, predecessors,
                  duration_seconds)
    print("PASS INTER_FPGA duration_seconds=%d fitted_rx_lanes_per_endpoint=54 errors=0" %
          duration_seconds, flush=True)


def wait_for_simultaneous_run(boxes, timeout=10):
    deadline = time.monotonic() + timeout
    while True:
        states = dict((site, boxes[site].read_u32(0xc8))
                      for site in ("F1", "F2"))
        if all((state & 0xf) == 2 and
               (state & (SESSION_ACTIVE | SESSION_READY)) ==
               (SESSION_ACTIVE | SESSION_READY)
               for state in states.values()):
            print("OBSERVED simultaneous RUN with all-quad TX session ready",
                  flush=True)
            return
        require(time.monotonic() < deadline,
                "simultaneous RUN was not observed; no retry")
        time.sleep(.01)


def _run_external(registry, boxes, receive_masks, predecessors,
                  duration_seconds):
    duration_ms = validate_duration(duration_seconds)
    session_lease_ms = duration_ms + 60000
    predecessors = resolve_predecessors(boxes, predecessors)
    telemetry_snapshot(registry, "pre")
    for site in ("F1", "F2"):
        check_ready(site, boxes[site], *predecessors[site])
    # Firmware requires the complete managed mask for a TX session.  This
    # necessarily drives all 56 FireFly TXs as well as the 56 direct TXs.
    try:
        for site in ("F1", "F2"):
            seq, run = predecessors[site]
            submit(site, boxes[site], seq, seq + 1, 2, session_lease_ms,
                   ALL_MASK)
            require(wait_response(site, boxes[site], seq + 1, 5) == 0 and
                    boxes[site].read_u32(0xf8) == run,
                    site + " TX-session-start response/run mismatch")
            require(boxes[site].read_u32(0xc8) ==
                    (CAPABILITY | SESSION_ACTIVE | SESSION_READY),
                    site + " TX session did not become active")
        started = time.monotonic()
        for site in ("F1", "F2"):
            seq, run = predecessors[site]
            submit(site, boxes[site], seq + 1, seq + 2, 0x00010501,
                   duration_ms, receive_masks[site])
        wait_for_simultaneous_run(boxes)
        during_telemetry(registry, started, duration_seconds)
        for site in ("F1", "F2"):
            seq, run = predecessors[site]
            wait_response(site, boxes[site], seq + 2, duration_seconds + 40)
            validate_records(site, boxes[site], receive_masks[site], run + 1,
                             duration_ms)
    finally:
        for site in ("F1", "F2"):
            box = boxes[site]
            seq, run = predecessors[site]
            try:
                current_sequence = box.read_u32(0xa0)
                if (box.read_u32(0xc8) & SESSION_ACTIVE and
                        box.read_u32(0xc8) & 0x1ffff == 0 and
                        current_sequence in (seq + 1, seq + 2)):
                    published_run = box.read_u32(0xf8)
                    submit(site, box, current_sequence, current_sequence + 1,
                           3, 0, ALL_MASK)
                    require(wait_response(site, box, current_sequence + 1, 5) == 0 and
                            box.read_u32(0xf8) == published_run,
                            site + " TX-session-stop response/run mismatch")
                else:
                    print("CLEANUP site=%s no-stop-issued state=%#x sequence=%d; %dms lease bounds TX" %
                          (site, box.read_u32(0xc8), box.read_u32(0xa0),
                           session_lease_ms), flush=True)
            except Exception as error:
                print("CLEANUP_ERROR site=%s error=%s; do not retry; %dms lease bounds TX" %
                      (site, error, session_lease_ms), flush=True)
    for site in ("F1", "F2"):
        require(boxes[site].read_u32(0xc8) == CAPABILITY,
                site + " not healthy IDLE/session-off after external test")
    telemetry_snapshot(registry, "post")
