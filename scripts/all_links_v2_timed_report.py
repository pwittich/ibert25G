#!/usr/bin/env python3
"""Create an immutable Markdown summary from one timed-test evidence log."""
import ast
import datetime
import hashlib
import re
import shlex
from pathlib import Path

from all_links_v2_timed_contract import BIT_SHA256, DCP_SHA256, ELF_SHA256, VERSION


KEY_VALUE = re.compile(r"([A-Za-z0-9_]+)=([^ ]+)")
RECORD = re.compile(r"^RECORD site=(F[12]) run=(\d+) lane=(\d+) data=(\{.*\})$")


def _fields(line):
    return dict(KEY_VALUE.findall(line))


def _argument(arguments, option, default="not recorded"):
    try:
        return arguments[arguments.index(option) + 1]
    except (ValueError, IndexError):
        return default


def _float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _escape(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def _parse(lines):
    parsed = {"clocks": [], "power": [], "fpga": [], "lga": [],
              "firefly": [], "records": [], "pass_markers": []}
    for line in lines:
        if line.startswith("CLOCK "):
            parsed["clocks"].append(_fields(line))
        elif line.startswith("POWER12V "):
            parsed["power"].append(_fields(line))
        elif line.startswith("FPGA_DIODE_TEMP "):
            parsed["fpga"].append(_fields(line))
        elif line.startswith("LGA80D_TEMP "):
            parsed["lga"].append(_fields(line))
        elif line.startswith("FIREFLY_TEMP "):
            parsed["firefly"].append(_fields(line))
        elif line.startswith("PASS "):
            parsed["pass_markers"].append(line)
        else:
            match = RECORD.match(line)
            if match:
                data = ast.literal_eval(match.group(4))
                data.update(site=match.group(1), run=int(match.group(2)),
                            lane=int(match.group(3)))
                parsed["records"].append(data)
    return parsed


def _clock_summary(clocks, site):
    values = dict((item["name"], int(item["khz"])) for item in clocks
                  if item.get("site") == site)
    required_ref_registers = set(("%02d" % value for value in
                                  (11, 12, 14, 15, 16, 17, 18, 19,
                                   20, 21, 22, 23)))
    refs = [int(item["khz"]) for item in clocks
            if item.get("site") == site and
            item.get("r") in required_ref_registers]
    required_ok = (len(values) == 37 and values.get("clk_200_ext") == 200000 and
                   values.get("clk_100") == 100000 and
                   values.get("clk_325") == 325000 and len(refs) == 12 and
                   all(abs(value - 322266) < 323 for value in refs))
    ref_range = "%d–%d" % (min(refs), max(refs)) if refs else "not recorded"
    return ("PASS" if required_ok else "INCOMPLETE/FAIL",
            len(values), values.get("clk_200_ext", "—"),
            values.get("clk_100", "—"), values.get("clk_325", "—"),
            ref_range)


def _telemetry_rows(parsed):
    labels = []
    for category in ("power", "fpga", "lga", "firefly"):
        for item in parsed[category]:
            label = item.get("label")
            if label not in labels:
                labels.append(label)
    rows = []
    for label in labels:
        power = next((_float(item.get("watts")) for item in parsed["power"]
                      if item.get("label") == label), None)
        fpga = dict((item.get("sensor"), _float(item.get("celsius")))
                    for item in parsed["fpga"] if item.get("label") == label)
        lga = [_float(item.get("celsius")) for item in parsed["lga"]
               if item.get("label") == label]
        firefly = [_float(item.get("celsius")) for item in parsed["firefly"]
                   if item.get("label") == label]
        lga = [value for value in lga if value is not None]
        firefly = [value for value in firefly if value is not None]
        rows.append((label, "%.3f" % power if power is not None else "—",
                     "%.3f" % fpga["F1_TEMP"] if fpga.get("F1_TEMP") is not None else "—",
                     "%.3f" % fpga["F2_TEMP"] if fpga.get("F2_TEMP") is not None else "—",
                     "%.3f (%d readings)" % (max(lga), len(lga)) if lga else "—",
                     "%.3f (%d modules)" % (max(firefly), len(firefly)) if firefly else "—"))
    return rows


def _record_summary(records, site):
    selected = [item for item in records if item["site"] == site]
    passed = [item for item in selected
              if item.get("id_status") == 0x1800 + item["lane"] and
              item.get("errors") == 0 and item.get("lock_losses") == 0 and
              item.get("tested_bits", 0) > 0]
    bits = [item.get("tested_bits", 0) for item in selected]
    errors = sum(item.get("errors", 0) for item in selected)
    losses = sum(item.get("lock_losses", 0) for item in selected)
    bit_range = "%d–%d" % (min(bits), max(bits)) if bits else "not recorded"
    run_ids = sorted(set(item["run"] for item in selected))
    return (len(selected), len(passed), errors, losses, bit_range,
            ",".join(str(value) for value in run_ids) if run_ids else "—")


def write_report(evidence, script, arguments, evidence_tag, exit_code,
                 cm_interface_commit):
    """Write a sibling .report.md file once; return its path."""
    evidence = Path(evidence)
    report = evidence.with_suffix(".report.md")
    raw = evidence.read_bytes()
    lines = raw.decode("utf-8", errors="replace").splitlines()
    parsed = _parse(lines)
    passed = exit_code == 0 and len(parsed["pass_markers"]) == 1
    kind = ("FireFly external loopback" if "firefly" in script
            else "bidirectional inter-FPGA")
    duration = _argument(arguments, "--duration-seconds")
    quads = arguments[0] if "firefly" in script and arguments else "not applicable"
    generated = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    command = "python3 -u %s %s" % (
        script, " ".join(shlex.quote(str(value)) for value in arguments))

    output = [
        "# All-links v2 timed-test report", "",
        "## Outcome", "",
        "**%s**" % ("PASS" if passed else "FAIL"), "",
        "- Test: %s" % kind,
        "- Evidence tag: `%s`" % evidence_tag,
        "- Requested duration: %s seconds" % duration,
        "- FireFly receive selection: `%s`" % quads,
        "- Process exit code: %d" % exit_code,
        "- Report generated: %s" % generated,
        "- Evidence log: `%s`" % evidence,
        "- Evidence SHA-256: `%s`" % hashlib.sha256(raw).hexdigest(),
        "", "## Frozen inputs", "",
        "- Firmware/hardware identity: `0x%08x`" % VERSION,
        "- BIT SHA-256: `%s`" % BIT_SHA256,
        "- routed DCP SHA-256: `%s`" % DCP_SHA256,
        "- ELF SHA-256: `%s`" % ELF_SHA256,
        "- `cm_interface` commit: `%s`" % cm_interface_commit,
        "- Command: `%s`" % command.replace("`", "\\`"),
        "- Expected predecessor F1 sequence/run: %s/%s" %
        (_argument(arguments, "--f1-sequence"), _argument(arguments, "--f1-run")),
        "- Expected predecessor F2 sequence/run: %s/%s" %
        (_argument(arguments, "--f2-sequence"), _argument(arguments, "--f2-run")),
        "", "## Clock preflight", "",
        "| Site | Result | Counters | clk_200 | clk_100 | clk_325 | 12 GT references (kHz) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for site in ("F1", "F2"):
        status, count, clk200, clk100, clk325, refs = _clock_summary(parsed["clocks"], site)
        output.append("| %s | %s | %s/37 | %s | %s | %s | %s |" %
                      (site, status, count, clk200, clk100, clk325, refs))

    output.extend(["", "## Lane-result summary", "",
                   "| Site | Records | Clean | Error count sum | Native losses | Tested-bit range | Run IDs |",
                   "|---|---:|---:|---:|---:|---:|---:|"])
    for site in ("F1", "F2"):
        values = _record_summary(parsed["records"], site)
        output.append("| %s | %d | %d | %d | %d | %s | %s |" %
                      ((site,) + values))

    failed_records = [item for item in parsed["records"]
                      if item.get("id_status") != 0x1800 + item["lane"] or
                      item.get("errors") != 0 or item.get("lock_losses") != 0 or
                      item.get("tested_bits", 0) == 0]
    if failed_records:
        output.extend(["", "### Non-clean lane records", "",
                       "| Site | Lane | id_status | Errors | Native losses | Tested bits |",
                       "|---|---:|---:|---:|---:|---:|"])
        for item in failed_records:
            output.append("| %s | %d | `0x%04x` | %d | %d | %d |" %
                          (item["site"], item["lane"], item.get("id_status", 0),
                           item.get("errors", 0), item.get("lock_losses", 0),
                           item.get("tested_bits", 0)))

    output.extend(["", "## Telemetry summary", "",
                   "| Snapshot | 12-V power (W) | F1 diode (°C) | F2 diode (°C) | Max LGA80D (°C) | Max FireFly (°C) |",
                   "|---|---:|---:|---:|---:|---:|"])
    rows = _telemetry_rows(parsed)
    if rows:
        for row in rows:
            output.append("| %s | %s | %s | %s | %s | %s |" %
                          tuple(_escape(value) for value in row))
    else:
        output.append("| not recorded | — | — | — | — | — |")

    output.extend(["", "## Completion marker", ""])
    if parsed["pass_markers"]:
        for marker in parsed["pass_markers"]:
            output.append("- `%s`" % marker)
    else:
        output.append("No PASS marker was recorded.")
    if not passed:
        output.extend(["", "## Failure tail", "", "```text"])
        output.extend(lines[-20:] if lines else ["Evidence log is empty."])
        output.append("```")
    output.extend(["", "The evidence log is authoritative; this report is a derived summary.", ""])

    with report.open("x", encoding="utf-8") as stream:
        stream.write("\n".join(output))
    return report
