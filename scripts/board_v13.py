#!/usr/bin/env python3
"""Deploy or operate only the fixed fresh v13 external smoke.

The helper is deliberately limited to deploying its two hash-verified test
files and to the fresh sequence-1 v13 smoke stages.  Each stage preserves its
stdout/stderr in a new local evidence log.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v13-external-smoke-20260914"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
FILES = ("milestone3_v13_external_smoke.py",
         "milestone3_12hour_external_soak.py")


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
        local_hash = hashlib.sha256(
            (ROOT / "scripts" / name).read_bytes()).hexdigest()
        if remote_hashes.get(name) != local_hash:
            raise RuntimeError("remote hash mismatch: " + name)
    print("V13_SMOKE_DEPLOY_VERIFIED " + REMOTE_DIR)


def log_path(stage):
    archive = ROOT / "build" / "diagnostic_archive"
    return archive / ("v13-external-smoke-{}-{}.log".format(
        stage, int(time.time())))


def run_stage(stage):
    local = log_path(stage)
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    command = (
        "cd {} && python3 -u milestone3_v13_external_smoke.py {} "
        "--cm-interface-root /home/cms/25G/cm_interface"
    ).format(REMOTE_DIR, stage)
    process = subprocess.Popen(
        SSH + [command], cwd=str(ROOT), stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, universal_newlines=True)
    with local.open("x") as evidence:
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            evidence.write(line)
            evidence.flush()
    status = process.wait()
    print("V13_SMOKE_EVIDENCE " + str(local))
    if status:
        raise RuntimeError(
            "v13 external smoke {} failed after preserving evidence".format(
                stage))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("deploy", "start", "status",
                                              "results"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    else:
        run_stage(args.operation)


if __name__ == "__main__":
    main()
