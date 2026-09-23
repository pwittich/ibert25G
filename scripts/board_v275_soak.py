#!/usr/bin/env python3
"""Deploy or operate only the fixed v275 sequence-3 12-hour F1 soak."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v275-soak3-20260913"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
FILES = ("milestone275_12hour.py", "milestone3_12hour_external_soak.py")


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
    print("V275_SOAK_DEPLOY_VERIFIED " + REMOTE_DIR)


def log_path(stage):
    archive = ROOT / "build" / "diagnostic_archive"
    if stage in ("start", "results"):
        return archive / ("v275-soak3-" + stage + ".log")
    return archive / ("v275-soak3-status-" + str(int(time.time())) + ".log")


def run_stage(stage):
    local = log_path(stage)
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    command = "cd {} && python3 -u milestone275_12hour.py {}".format(
        REMOTE_DIR, stage)
    process = subprocess.Popen(SSH + [command], cwd=str(ROOT),
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               universal_newlines=True)
    with local.open("x") as evidence:
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            evidence.write(line)
            evidence.flush()
    status = process.wait()
    print("V275_SOAK_EVIDENCE " + str(local))
    if status:
        raise RuntimeError("v275 soak {} failed after preserving evidence".format(stage))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("deploy", "start", "status", "results"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    else:
        run_stage(args.operation)


if __name__ == "__main__":
    main()
