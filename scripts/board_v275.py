#!/usr/bin/env python3
"""Deploy or run the fixed v275 F1 qualification-candidate clean gate.

No programming, resets, retries, arbitrary commands, paths, or sequences.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v275-qualification-20260913"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
FILES = (
    "milestone275_characterize.py",
    "milestone268_characterize.py",
    "milestone268_diagnostics.py",
    "milestone3_12hour_external_soak.py",
    "recovery_diagnostics.py",
    "transition_diagnostics.py",
)
RUNS = {
    "clean1": (1, 0, 1, "v275-clean1.json"),
    "clean2": (2, 1, 2, "v275-clean2.json"),
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
    print("V275_DEPLOY_VERIFIED " + REMOTE_DIR)


def retrieve(remote_file, local):
    checked(SCP + [REMOTE + ":" + remote_file, str(local)])
    print("V275_EVIDENCE " + str(local))


def run_clean(name):
    sequence, previous, run_id, filename = RUNS[name]
    local = ROOT / "build" / "diagnostic_archive" / filename
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    remote_file = REMOTE_DIR + "/" + filename
    command = (
        "cd {d} && python3 -u milestone275_characterize.py "
        "--sequence {s} --previous-sequence {p} --expected-run-id {r} "
        "--duration-ms 10000 --stimulus clean --output {f}"
    ).format(d=REMOTE_DIR, s=sequence, p=previous, r=run_id, f=filename)
    status = subprocess.run(SSH + [command], cwd=str(ROOT)).returncode
    # Preserve raw evidence even if the remote validator reports failure.
    retrieve(remote_file, local)
    if status:
        raise RuntimeError("v275 clean baseline failed after preserving evidence")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("deploy", "clean1", "clean2"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    else:
        run_clean(args.operation)


if __name__ == "__main__":
    main()
