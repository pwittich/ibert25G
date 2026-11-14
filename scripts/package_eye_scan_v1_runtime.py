#!/usr/bin/env python3
"""Create an exclusive local runtime bundle; no deployment or board access."""
import hashlib
import json
from pathlib import Path
import shutil
import time
import eye_scan_v1_contract as contract


def package(destination=None):
    source = Path(__file__).resolve().parent
    destination = Path(destination or source.parent / "build" /
                       ("eye_scan_v1_runtime_%d" % int(time.time() * 1000000)))
    destination.mkdir(parents=True, exist_ok=False)
    files = {}
    for name in contract.RUNTIME_FILES:
        shutil.copy2(str(source / name), str(destination / name))
        digest = hashlib.sha256((source / name).read_bytes()).hexdigest()
        if hashlib.sha256((destination / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError("runtime copy hash mismatch: " + name)
        files[name] = digest
    manifest = dict(schema=1, version=contract.VERSION, released=contract.RELEASED,
                    files=files, bit=contract.BIT_SHA256, dcp=contract.DCP_SHA256,
                    elf=contract.ELF_SHA256, cm_commit=contract.CM_COMMIT)
    with (destination / "eye_scan_v1_runtime_manifest.json").open("x") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print("EYE_RUNTIME_BUNDLE %s files=%d released=%s" % (destination, len(files), contract.RELEASED))
    return destination


if __name__ == "__main__":
    package()
