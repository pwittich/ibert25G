#!/usr/bin/env python3
"""Deploy or operate the fixed FireFly-1 v4 PMA-loopback hardware gate."""
import argparse
import hashlib
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/firefly1-loopback-v4-20260916"
FILES = ("firefly1_loopback_v4_remote.py", "milestone3_12hour_external_soak.py")
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL, "-o", "BatchMode=yes"]
STAGES = ("deploy", "start", "status", "results", "diagnostics")
REMOTE_ARGS = ""
EVIDENCE_PREFIX = "firefly1-v4"

def checked(argv):
    return subprocess.run(argv, cwd=str(ROOT), check=True)

def deploy():
    checked(SSH + ["mkdir -p " + REMOTE_DIR])
    checked(SCP + [str(ROOT / "scripts" / name) for name in FILES] + [REMOTE + ":" + REMOTE_DIR + "/"])
    output = subprocess.check_output(SSH + ["cd " + REMOTE_DIR + " && sha256sum " + " ".join(FILES)], cwd=str(ROOT), universal_newlines=True)
    hashes = dict((line.split()[1], line.split()[0]) for line in output.splitlines())
    for name in FILES:
        if hashes.get(name) != hashlib.sha256((ROOT / "scripts" / name).read_bytes()).hexdigest():
            raise RuntimeError("remote hash mismatch: " + name)
    print("FIREFLY1_V4_DEPLOY_VERIFIED " + REMOTE_DIR)

def run(stage):
    evidence = ROOT / "build" / "diagnostic_archive" / ("%s-%s-%d.log" % (EVIDENCE_PREFIX, stage, int(time.time())))
    if evidence.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(evidence))
    command = "cd %s && python3 -u firefly1_loopback_v4_remote.py %s --cm-interface-root /home/cms/25G/cm_interface" % (REMOTE_DIR, stage)
    command += REMOTE_ARGS
    process = subprocess.Popen(SSH + [command], cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    with evidence.open("x") as stream:
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            stream.write(line)
            stream.flush()
    if process.wait():
        raise RuntimeError("stage failed; evidence " + str(evidence))
    print("FIREFLY1_V4_EVIDENCE " + str(evidence))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=STAGES)
    args = parser.parse_args()
    if args.stage == "deploy":
        deploy()
    else:
        run(args.stage)

if __name__ == "__main__":
    main()
