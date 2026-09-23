#!/usr/bin/env python3
"""Deploy or operate only two fixed fresh v15 external smoke requests.

Each non-deploy stage streams into a newly named local evidence log. This
helper has no retry or reconfiguration operation. The two start operations
are pinned to fresh request histories (sequence 1 after 0, then 2 after 1).
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v15-qualification-candidate-20260914"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
FILES = ("milestone3_v15_external_smoke.py", "milestone3_12hour_external_soak.py")
RUNS = {
    "start": ("start", 1, 0), "status": ("status", 1, 0),
    "results": ("results", 1, 0), "start2": ("start", 2, 1),
    "status2": ("status", 2, 1), "results2": ("results", 2, 1),
}


def checked(argv):
    return subprocess.run(argv, cwd=str(ROOT), check=True)


def deploy():
    checked(SSH + ["mkdir -p " + REMOTE_DIR])
    checked(SCP + [str(ROOT / "scripts" / name) for name in FILES] +
            [REMOTE + ":" + REMOTE_DIR + "/"])
    output = subprocess.check_output(
        SSH + ["cd " + REMOTE_DIR + " && sha256sum " + " ".join(FILES)],
        cwd=str(ROOT), universal_newlines=True)
    remote_hashes = {line.split()[1]: line.split()[0]
                     for line in output.splitlines()}
    for name in FILES:
        local_hash = hashlib.sha256((ROOT / "scripts" / name).read_bytes()).hexdigest()
        if remote_hashes.get(name) != local_hash:
            raise RuntimeError("remote hash mismatch: " + name)
    print("V15_SMOKE_DEPLOY_VERIFIED " + REMOTE_DIR)


def log_path(stage):
    return ROOT / "build" / "diagnostic_archive" / (
        "v15-external-smoke-{}-{}.log".format(stage, int(time.time())))


def run_stage(operation):
    stage, sequence, previous = RUNS[operation]
    local = log_path(stage)
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    command = ("cd {} && python3 -u milestone3_v15_external_smoke.py {} "
               "--sequence {} --previous-sequence {} "
               "--cm-interface-root /home/cms/25G/cm_interface").format(
                   REMOTE_DIR, stage, sequence, previous)
    process = subprocess.Popen(SSH + [command], cwd=str(ROOT), stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, universal_newlines=True)
    with local.open("x") as evidence:
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            evidence.write(line)
            evidence.flush()
    status = process.wait()
    print("V15_SMOKE_EVIDENCE " + str(local))
    if status:
        raise RuntimeError("v15 external smoke {} failed after preserving evidence".format(operation))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=(
        "deploy", "start", "status", "results", "start2", "status2", "results2"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    else:
        run_stage(args.operation)


if __name__ == "__main__":
    main()
