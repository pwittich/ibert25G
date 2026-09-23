#!/usr/bin/env python3
"""Deploy or run the fixed v274 F1 heartbeat-detector hardware gate."""
import argparse
import hashlib
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v274-diagnostic-20260913"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
XSDB_SSH = ["ssh", "-F", "/dev/null", "-S",
            "/home/wittich/.ssh/master-pw94@lnx4189:22", "-o",
            "BatchMode=yes", "-o", "ConnectTimeout=10", "pw94@lnx4189"]
FILES = (
    "milestone274_characterize.py", "milestone274_heartbeat.py",
    "milestone268_characterize.py", "milestone268_diagnostics.py",
    "milestone3_12hour_external_soak.py", "recovery_diagnostics.py",
    "transition_diagnostics.py",
)


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
    print("V274_DEPLOY_VERIFIED " + REMOTE_DIR)


def retrieve(remote_file, local):
    checked(SCP + [REMOTE + ":" + remote_file, str(local)])
    print("V274_EVIDENCE " + str(local))


def clean1():
    local = ROOT / "build" / "diagnostic_archive" / "v274-clean1.json"
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    remote_file = REMOTE_DIR + "/v274-clean1.json"
    command = ("cd {d} && python3 -u milestone274_characterize.py "
               "--sequence 1 --previous-sequence 0 --expected-run-id 1 "
               "--duration-ms 10000 --stimulus clean --output v274-clean1.json").format(d=REMOTE_DIR)
    status = subprocess.run(SSH + [command], cwd=str(ROOT)).returncode
    retrieve(remote_file, local)
    if status:
        raise RuntimeError("v274 clean baseline failed after preserving evidence")


def heartbeat2():
    local = ROOT / "build" / "diagnostic_archive" / "v274-heartbeat2.json"
    log = ROOT / "build" / "v274-run2-heartbeat-xsdb.log"
    if local.exists() or log.exists():
        raise RuntimeError("refusing to overwrite v274 heartbeat evidence")
    watcher = subprocess.Popen(XSDB_SSH + [
        "flock -n /tmp/pw94-apollo3010-f1-heartbeat.lock "
        "/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb "
        "/nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/"
        "milestone274_heartbeat.tcl"], cwd=str(ROOT), stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, universal_newlines=True)
    while True:
        line = watcher.stdout.readline()
        if line:
            print(line, end="")
            if "ARMED v274" in line:
                break
        elif watcher.poll() is not None:
            raise RuntimeError("heartbeat watcher failed before arming; no run submitted")
    remote_file = REMOTE_DIR + "/v274-heartbeat2.json"
    command = ("cd {d} && python3 -u milestone274_heartbeat.py "
               "--sequence 2 --previous-sequence 1 --expected-run-id 2 "
               "--duration-ms 10000 --output v274-heartbeat2.json").format(d=REMOTE_DIR)
    run_status = subprocess.run(SSH + [command], cwd=str(ROOT)).returncode
    remaining, unused = watcher.communicate()
    print(remaining, end="")
    watcher_status = watcher.returncode
    retrieve(remote_file, local)
    if run_status or watcher_status:
        raise RuntimeError("v274 heartbeat gate failed after preserving evidence")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("deploy", "clean1", "heartbeat2"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    elif args.operation == "clean1":
        clean1()
    else:
        heartbeat2()


if __name__ == "__main__":
    main()
