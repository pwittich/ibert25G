#!/usr/bin/env python3
"""Deploy or operate only the fixed v15 sequence-3 12-hour F1 soak."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v15-soak3-20260915"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL, "-o", "BatchMode=yes"]
FILES = ("milestone3_v15_12hour.py", "milestone3_12hour_external_soak.py")

def checked(argv):
    return subprocess.run(argv, cwd=str(ROOT), check=True)

def deploy():
    checked(SSH + ["mkdir -p " + REMOTE_DIR])
    checked(SCP + [str(ROOT / "scripts" / name) for name in FILES] + [REMOTE + ":" + REMOTE_DIR + "/"])
    output = subprocess.check_output(SSH + ["cd " + REMOTE_DIR + " && sha256sum " + " ".join(FILES)], cwd=str(ROOT), universal_newlines=True)
    remote_hashes = {line.split()[1]: line.split()[0] for line in output.splitlines()}
    for name in FILES:
        if remote_hashes.get(name) != hashlib.sha256((ROOT / "scripts" / name).read_bytes()).hexdigest():
            raise RuntimeError("remote hash mismatch: " + name)
    print("V15_SOAK_DEPLOY_VERIFIED " + REMOTE_DIR)

def run(stage):
    archive = ROOT / "build" / "diagnostic_archive"
    suffix = stage if stage in ("start", "results") else stage + "-" + str(int(time.time()))
    local = archive / ("v15-soak3-" + suffix + ".log")
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    process = subprocess.Popen(SSH + ["cd {} && python3 -u milestone3_v15_12hour.py {}".format(REMOTE_DIR, stage)], cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    with local.open("x") as evidence:
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            evidence.write(line); evidence.flush()
    if process.wait():
        raise RuntimeError("v15 soak {} failed after preserving evidence".format(stage))
    print("V15_SOAK_EVIDENCE " + str(local))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("deploy", "start", "status", "results"))
    args = parser.parse_args()
    deploy() if args.operation == "deploy" else run(args.operation)

if __name__ == "__main__":
    main()
