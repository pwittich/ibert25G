#!/usr/bin/env python3
"""Deploy or run the fixed v273 hardware-gate sequence on F1.

No programming, resets, retries, arbitrary commands, paths, or sequences.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/tmp/v273-diagnostic-20260913"
SSH = ["ssh", "-F", "/dev/null", "-S", CONTROL, "-o", "BatchMode=yes",
       "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
XSDB_SSH = ["ssh", "-F", "/dev/null", "-S",
            "/home/wittich/.ssh/master-pw94@lnx4189:22", "-o",
            "BatchMode=yes", "-o", "ConnectTimeout=10", "pw94@lnx4189"]
FILES = (
    "milestone273_characterize.py",
    "milestone268_characterize.py",
    "milestone268_diagnostics.py",
    "milestone3_12hour_external_soak.py",
    "recovery_diagnostics.py",
    "transition_diagnostics.py",
    "milestone272_runtime_integrity.py",
    "milestone273_runtime_integrity.py",
)
RUNS = {
    "clean1": (1, 0, 1, "v273-planned-startup-clean1.json"),
    "clean2": (2, 1, 2, "v273-planned-startup-clean2.json"),
    "pulse4": (4, 3, 4, "v273-run4-pulse.json"),
}


def checked(argv):
    return subprocess.run(argv, cwd=str(ROOT), check=True)


def deploy():
    checked(SSH + ["mkdir -p " + REMOTE_DIR])
    sources = [str(ROOT / "scripts" / name) for name in FILES]
    checked(SCP + sources + [REMOTE + ":" + REMOTE_DIR + "/"])
    output = subprocess.check_output(
        SSH + ["cd " + REMOTE_DIR + " && sha256sum " + " ".join(FILES)],
        cwd=str(ROOT), universal_newlines=True)
    remote_hashes = {line.split()[1]: line.split()[0]
                     for line in output.splitlines()}
    for name in FILES:
        local_hash = hashlib.sha256((ROOT / "scripts" / name).read_bytes()).hexdigest()
        if remote_hashes.get(name) != local_hash:
            raise RuntimeError("remote hash mismatch: " + name)
    print("V273_DEPLOY_VERIFIED " + REMOTE_DIR)


def retrieve(remote_file, local):
    checked(SCP + [REMOTE + ":" + remote_file, str(local)])
    print("V273_EVIDENCE " + str(local))


def run_characterization(name):
    sequence, previous, run_id, filename = RUNS[name]
    local = ROOT / "build" / "diagnostic_archive" / filename
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    remote_file = REMOTE_DIR + "/" + filename
    stimulus = "external-pulse" if name == "pulse4" else "clean"
    command = (
        "cd {d} && python3 -u milestone273_characterize.py "
        "--sequence {s} --previous-sequence {p} --expected-run-id {r} "
        "--duration-ms 10000 --stimulus {t} --output {f}"
    ).format(d=REMOTE_DIR, s=sequence, p=previous, r=run_id,
             t=stimulus, f=filename)
    watcher = None
    if name == "pulse4":
        pulse_log = ROOT / "build" / "v273-run4-xsdb.log"
        if pulse_log.exists():
            raise RuntimeError("refusing to overwrite pulse evidence: " + str(pulse_log))
        watcher = subprocess.Popen(XSDB_SSH + [
            "flock -n /tmp/pw94-apollo3010-f1-pulse.lock "
            "/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb "
            "/nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/"
            "milestone273_pulse.tcl"], cwd=str(ROOT), stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, universal_newlines=True)
        # Do not submit the descriptor until XSDB has verified the exact IDLE
        # predecessor state. This closes the race exposed by the preserved,
        # no-write sequence-3 launcher failure.
        while True:
            line = watcher.stdout.readline()
            if line:
                print(line, end="")
                if "ARMED v273" in line:
                    break
            elif watcher.poll() is not None:
                raise RuntimeError("pulse watcher failed before arming; no run submitted")
    run_status = subprocess.run(SSH + [command], cwd=str(ROOT)).returncode
    if watcher is not None:
        remaining, unused = watcher.communicate()
        print(remaining, end="")
        watcher_status = watcher.returncode
    else:
        watcher_status = 0
    # The operator saves raw evidence before validation, so retrieve it even
    # when validation reports a failure. SCP failure remains fatal.
    retrieve(remote_file, local)
    if run_status or watcher_status:
        raise RuntimeError("remote diagnostic failed after preserving evidence")


def run_firefly5():
    filename = "v273-run5-firefly250ms.json"
    local = ROOT / "build" / "diagnostic_archive" / filename
    if local.exists():
        raise RuntimeError("refusing to overwrite evidence: " + str(local))
    remote_file = REMOTE_DIR + "/" + filename
    command = (
        "cd {d} && python3 -u milestone273_runtime_integrity.py "
        "--sequence 5 --previous-sequence 4 --expected-run-id 5 "
        "--disable-ms 250 --duration-ms 10000 --output {f}"
    ).format(d=REMOTE_DIR, f=filename)
    run_status = subprocess.run(SSH + [command], cwd=str(ROOT)).returncode
    retrieve(remote_file, local)
    if run_status:
        raise RuntimeError("remote integrity gate failed after preserving evidence")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=(
        "deploy", "clean1", "clean2", "pulse4", "firefly5"))
    args = parser.parse_args()
    if args.operation == "deploy":
        deploy()
    elif args.operation == "firefly5":
        run_firefly5()
    else:
        run_characterization(args.operation)


if __name__ == "__main__":
    main()
