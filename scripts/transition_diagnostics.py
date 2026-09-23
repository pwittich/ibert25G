#!/usr/bin/env python3
"""Offline decoders for the v268 diagnostic-only transition/profile pages."""


def metadata(words):
    if len(words) != 8 or words[0] not in (0x54520001, 0x54520002):
        raise ValueError("unsupported transition trace schema")
    flags = words[1]
    width = 6 if words[0] == 0x54520001 else 8
    capacity = 1 << width
    result = dict(active=bool(flags & (1 << (2 * width + 3))),
                  overflow=bool(flags & (1 << (2 * width + 2))),
                  count=(flags >> (width + 1)) & (2 * capacity - 1),
                  next_index=(flags >> 1) & (capacity - 1),
                  capacity=capacity, epoch=words[2], events=words[3])
    if result["count"] > capacity:
        raise ValueError("invalid trace count")
    return result


def chronological(meta, entries):
    if meta["active"]:
        raise ValueError("trace is not frozen")
    capacity = meta["capacity"]
    if len(entries) != capacity:
        raise ValueError("expected all {} physical slots".format(capacity))
    start = meta["next_index"] if meta["count"] == capacity else 0
    return [entry(entries[(start + n) % capacity]) for n in range(meta["count"])]


def entry(words):
    if len(words) != 8:
        raise ValueError("expected eight trace words")
    quad, rx, prbs, raw, selects, engine = words[2:]
    return dict(tick=words[0] | (words[1] << 32), quad=quad,
                acquisition=rx, prbs=prbs, pins=raw, selects=selects,
                engine=engine, engine_state=(engine >> 8) & 15,
                prbs_state=prbs & 31, quad_state=(quad >> 16) & 7,
                measure=bool(engine & 64), start_request=(engine >> 4) & 1,
                stop_request=(engine >> 3) & 1,
                start_ack=(engine >> 16) & 15, stop_ack=(engine >> 12) & 15)


def profile(words):
    if len(words) != 8 or words[0] != 0x45520001 or words[6] != 1:
        raise ValueError("native RX profile unavailable or incomplete")
    if any(w == 0xffffffff for w in words[1:6]):
        raise ValueError("profile saturated; shorten measurement")
    elapsed, errors, maximum, first, last = words[1:6]
    if not elapsed or errors > elapsed or maximum > errors:
        raise ValueError("inconsistent RX profile")
    if errors and not (first <= last < elapsed):
        raise ValueError("invalid error span")
    return dict(elapsed=elapsed, errors=errors, maximum_consecutive=maximum,
                first_error=first, last_error=last,
                error_span=(last - first + 1) if errors else 0,
                error_duty=float(errors) / elapsed)
