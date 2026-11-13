#!/usr/bin/env python3
"""Prepare a local, exclusive v3 runtime bundle. Never deploy or access MCU."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time

FILES = (
    "board_all_links_v3.py", "all_links_v3_contract.py",
    "all_links_v2_timed_common.py", "all_links_v2_timed_contract.py",
    "milestone3_12hour_external_soak.py",
    "enable_all_links_v3_inter_fpga.py", "test_all_links_v3_firefly_loopback.py",
)


def package(destination, source=None):
    source = Path(source or Path(__file__).resolve().parent)
    destination = Path(destination)
    destination.mkdir()  # Exclusive; an existing bundle is never overwritten.
    hashes = {}
    for name in FILES:
        data = (source / name).read_bytes()
        hashes[name] = hashlib.sha256(data).hexdigest()
        shutil.copyfile(str(source / name), str(destination / name))
    (destination / "all_links_v3_runtime_manifest.json").write_text(
        json.dumps({"schema": 1, "files": hashes}, indent=2, sort_keys=True) + "\n")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    destination = args.destination or root / "build" / (
        "all_links_v3_runtime_bundle_%d" % int(time.time() * 1000000))
    package(destination)
    print("Prepared local runtime bundle: " + str(destination))
    print("No deployment; the bundle retains the source contract's release state.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
