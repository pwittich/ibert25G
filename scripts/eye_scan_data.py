"""Offline eye-scan encoding, raw-count validation, CSV export and plotting."""
import csv
import math
import os
from pathlib import Path
import tempfile

SCHEMA = "eye-scan-v1/1"
LINE_RATE = 25781250000
QUADS = tuple(range(121, 135)) + tuple(range(221, 235))


def signed(value, width):
    return value - (1 << width) if value & (1 << (width - 1)) else value


def axis(spec, low, high, max_step):
    try:
        first, last, step = (int(s) for s in spec.split(":"))
    except (ValueError, TypeError):
        raise ValueError("axis must be first:last:step")
    if not low <= first <= last <= high or not 1 <= step <= max_step:
        raise ValueError("axis outside supported bounds")
    return tuple(range(first, last + 1, step))


def descriptor(quad, lane, horizontal, vertical, prescale, budget_ms, point_ms):
    if quad not in QUADS or lane not in range(4):
        raise ValueError("select q121-q134 or q221-q234 and lane 0-3")
    xs = axis(horizontal, -32, 32, 32)
    ys = axis(vertical, -127, 127, 127)
    if len(xs) * len(ys) > 4096:
        raise ValueError("matrix exceeds 4096 points")
    if not isinstance(prescale, int) or not 0 <= prescale <= 31:
        raise ValueError("prescale must be 0-31")
    if not 10 < budget_ms <= 86340000 or not 1 <= point_ms <= 21474:
        raise ValueError("scan/session or management-cycle deadline outside bounds")
    maximum_dwell = (65535 * 80 * (1 << (prescale + 1))) / float(LINE_RATE)
    if point_ms / 1000.0 < maximum_dwell + .01:
        raise ValueError("point deadline cannot cover a zero-error counter accumulation at this prescale")
    # Includes bounded handshake/restore margin; a runtime deadline still
    # cancels safely if the real device violates this estimate.
    if budget_ms / 1000.0 < len(xs) * len(ys) * (maximum_dwell + .001) + 1:
        raise ValueError("scan budget too short for the requested matrix")
    global_lane = QUADS.index(quad) * 4 + lane
    h = global_lane | ((xs[0] & 127) << 7) | ((xs[-1] & 127) << 14) | (
        (int(horizontal.split(":")[2])) << 21)
    v = (ys[0] & 255) | ((ys[-1] & 255) << 8) | ((int(vertical.split(":")[2])) << 16)
    return dict(global_lane=global_lane, quad=quad, lane=lane, xs=xs, ys=ys,
                prescale=prescale, budget_ms=budget_ms, point_timeout_cycles=point_ms * 200000,
                words=(h, v, prescale, 0), max_dwell_seconds=maximum_dwell)


def decode_point(words, expected_job=None, expected_lane=None):
    if len(words) != 8 or any(type(w) is not int or not 0 <= w <= 0xffffffff for w in words):
        raise ValueError("point requires eight uint32 words")
    if words[0] != 0x45594401 or words[7] != 0x50020101:
        raise ValueError("unsupported eye point schema/profile")
    if expected_job is not None and words[1] != expected_job:
        raise ValueError("point belongs to another scan job")
    meta = words[2]
    lane, prescale = (meta >> 20) & 127, (meta >> 15) & 31
    if lane >= 112 or (expected_lane is not None and lane != expected_lane):
        raise ValueError("point lane mismatch")
    flags, status = (meta >> 4) & 3, (meta >> 6) & 255
    lpm, cleanup, fatal = bool(meta & (1 << 14)), bool(meta & 8), bool(meta & 4)
    e0, n0, e1, n1 = words[4] & 65535, words[4] >> 16, words[5] & 65535, words[5] >> 16
    b0, b1 = n0 * 80 * (1 << (prescale + 1)), n1 * 80 * (1 << (prescale + 1))
    complete = bool(meta & 1) and cleanup and not fatal and status == 0 and (
        flags == (1 if lpm else 3)) and b0 > 0 and (lpm or b1 > 0)
    if e0 > b0 or (not lpm and e1 > b1):
        complete = False
    ratio = ((e0 / float(b0)) if lpm else .5 * (e0 / float(b0) + e1 / float(b1))) if complete else None
    zero = complete and e0 == 0 and (lpm or e1 == 0)
    # Exact binomial zero-count bound. For DFE use a Bonferroni allocation
    # across both conditional UT ratios before averaging their upper bounds.
    upper = None
    if zero:
        alpha = .05 if lpm else .025
        upper = -math.expm1(math.log(alpha) / b0)
        if not lpm:
            upper = .5 * (upper - math.expm1(math.log(alpha) / b1))
    return dict(job=words[1], global_lane=lane, horizontal=signed(words[3] & 2047, 11),
                vertical=signed((words[3] >> 11) & 511, 9), prescale=prescale,
                lpm=lpm, vertical_range=(meta >> 27) & 3, status=status,
                cleanup_verified=cleanup, fatal=fatal, measurements=flags,
                errors0=e0, samples0=n0, errors1=e1, samples1=n1, bits0=b0, bits1=b1,
                elapsed_cycles=words[6], elapsed_saturated=bool(meta & (1 << 29)),
                complete=complete, mismatch_ratio=ratio, zero_errors=zero,
                zero_error_upper95=upper, raw_words=list(words))


def write_csv(path, points):
    fields = ("job", "global_lane", "horizontal", "vertical", "prescale", "lpm",
              "vertical_range", "status", "cleanup_verified", "fatal", "measurements",
              "errors0", "samples0", "errors1", "samples1", "bits0", "bits1",
              "elapsed_cycles", "elapsed_saturated", "complete", "mismatch_ratio",
              "zero_errors", "zero_error_upper95")
    with Path(path).open("x", newline="") as handle:
        writer = csv.DictWriter(handle, fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(points)


def plot(document, prefix):
    if document.get("schema") != SCHEMA:
        raise ValueError("unsupported eye-scan document schema")
    # Recompute from authoritative raw counters, never trust cached ratios.
    points = [decode_point(p["raw_words"], document["job"], document["global_lane"])
              for p in document["points"]]
    coordinates = [(p["horizontal"], p["vertical"]) for p in points]
    if len(set(coordinates)) != len(coordinates):
        raise ValueError("duplicate matrix coordinates")
    # Keep the complete requested extent when a failed scan/retrieval ends
    # before its last row. Otherwise missing rows silently disappear.
    requested = document.get("requested", {})
    xs = list(requested.get("xs", sorted(set(h for h, _ in coordinates))))
    ys = list(requested.get("ys", sorted(set(v for _, v in coordinates))))
    if (not xs or not ys or len(xs) * len(ys) > 4096 or
            any(type(x) is not int or not -32 <= x <= 32 for x in xs) or
            any(type(y) is not int or not -127 <= y <= 127 for y in ys) or
            xs != sorted(set(xs)) or ys != sorted(set(ys)) or
            any(h not in xs or v not in ys for h, v in coordinates)):
        raise ValueError("point coordinates outside the requested matrix")
    good = [p for p in points if p["complete"]]
    if not good:
        raise ValueError("no valid completed points to plot")
    os.environ.setdefault("MPLCONFIGDIR", str(Path(tempfile.gettempdir()) / "eye-scan-matplotlib"))
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LogNorm
    import numpy as np
    z = np.full((len(ys), len(xs)), np.nan)
    censored = []
    for p in good:
        z[ys.index(p["vertical"]), xs.index(p["horizontal"])] = (
            p["zero_error_upper95"] if p["zero_errors"] else p["mismatch_ratio"])
        if p["zero_errors"]:
            censored.append((p["horizontal"] / 64.0, p["vertical"]))
    fig = plt.figure(figsize=(11, 6.5))
    grid = fig.add_gridspec(2, 2, width_ratios=(1.6, 1))
    ax, horizontal_ax, vertical_ax = fig.add_subplot(grid[:, 0]), fig.add_subplot(grid[0, 1]), fig.add_subplot(grid[1, 1])
    floor = float(np.nanmin(z))
    mesh = ax.pcolormesh(np.array(xs) / 64.0, ys, np.ma.masked_invalid(z),
                         shading="nearest", cmap="viridis_r", norm=LogNorm(vmin=min(max(floor, 1e-18), .1), vmax=1))
    fig.colorbar(mesh, ax=ax, label="Eye-sampler mismatch ratio")
    if censored:
        ax.scatter(*zip(*censored), facecolors="none", edgecolors="white", s=10,
                   linewidths=.5, label="Zero errors: 95% upper bound")
        ax.legend(loc="upper right", fontsize=7)
    ax.set_xlabel("Horizontal offset (UI; 64 codes/UI)")
    ax.set_ylabel("Vertical offset (codes; no voltage calibration)")
    y_index = min((i for i in range(len(ys)) if np.isfinite(z[i]).any()), key=lambda i: abs(ys[i]))
    x_index = min((i for i in range(len(xs)) if np.isfinite(z[:, i]).any()), key=lambda i: abs(xs[i]))
    horizontal_ax.semilogy(np.array(xs) / 64.0, z[y_index], "o-", markersize=3)
    horizontal_ax.set_title("Horizontal slice at V=%d codes" % ys[y_index], fontsize=10)
    horizontal_ax.set_xlabel("Horizontal offset (UI)")
    vertical_ax.semilogy(ys, z[:, x_index], "o-", markersize=3)
    vertical_ax.set_title("Vertical slice at H=%d codes" % xs[x_index], fontsize=10)
    vertical_ax.set_xlabel("Vertical offset (codes)")
    for panel in (horizontal_ax, vertical_ax):
        panel.set_ylim(max(floor / 2, 1e-18), 1)
        panel.set_ylabel("Mismatch ratio")
        panel.grid(True, which="both", alpha=.2)
    title = "%s q%d lane%d — statistical eye" % (document["site"], document["quad"], document["lane"])
    if document.get("synthetic"):
        title = "SIMULATED DATA — " + title
    fig.suptitle(title)
    fig.text(.02, .015, "Zero-count bounds assume independent samples. Invalid/missing points are blank. "
             "This plot does not replace ordinary BER qualification.", fontsize=8)
    fig.tight_layout(rect=(0, .04, 1, .94))
    try:
        for suffix in ("png", "pdf"):
            with Path(str(prefix) + "." + suffix).open("xb") as handle:
                fig.savefig(handle, format=suffix, dpi=180)
    finally:
        plt.close(fig)
