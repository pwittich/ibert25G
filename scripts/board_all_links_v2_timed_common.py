#!/usr/bin/env python3
"""Hash-verified deployment and evidence capture for the two 90 s tests."""
import hashlib
import shlex
import subprocess
import time
from pathlib import Path

from all_links_v2_timed_report import write_report

ROOT = Path(__file__).resolve().parent.parent
REMOTE = "cms@apollo3010-1"
JUMP = "pw94@lnx4189"
CONTROL = "/home/wittich/.ssh/master-cms@apollo3010-1:22"
REMOTE_DIR = "/home/cms/25G"
CM_INTERFACE = Path("/nfs/cms/tracktrigger/wittich/int_test/cm_interface")
CM_INTERFACE_COMMIT = "8e56fdf24c038b64f69f26b55f0facb7c77e0537"
CM_INTERFACE_TAG = "v1.0.0"
SSH = ["ssh", "-F", "/dev/null", "-J", JUMP, "-S", CONTROL,
       "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", REMOTE]
SCP = ["scp", "-F", "/dev/null", "-J", JUMP,
       "-o", "ControlPath=" + CONTROL,
       "-o", "BatchMode=yes"]
FILES = (
    "all_links_v2_timed_contract.py",
    "all_links_v2_timed_common.py",
    "milestone3_12hour_external_soak.py",
    "all_links_v2_timed_status.py",
    "all_links_v2_timed_results.py",
    "test_all_links_v2_inter_fpga.py",
    "test_all_links_v2_firefly_loopback.py",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_remote():
    output = subprocess.check_output(
        SSH + ["cd %s && sha256sum %s" % (REMOTE_DIR, " ".join(FILES))],
        cwd=str(ROOT), universal_newlines=True)
    found = dict((line.split()[1], line.split()[0]) for line in output.splitlines())
    for name in FILES:
        if found.get(name) != digest(ROOT / "scripts" / name):
            raise RuntimeError("remote hash mismatch: " + name)
    output = subprocess.check_output(
        SSH + ["git -C %s/cm_interface status --porcelain && "
               "git -C %s/cm_interface rev-parse HEAD && "
               "git -C %s/cm_interface describe --tags --exact-match HEAD" %
               (REMOTE_DIR, REMOTE_DIR, REMOTE_DIR)],
        cwd=str(ROOT), universal_newlines=True)
    lines = output.splitlines()
    if lines != [CM_INTERFACE_COMMIT, CM_INTERFACE_TAG]:
        raise RuntimeError("remote authoritative cm_interface mismatch: " +
                           repr(lines))


def deploy():
    subprocess.run(SSH + ["mkdir -p " + REMOTE_DIR], cwd=str(ROOT), check=True)
    subprocess.run(SCP + [str(ROOT / "scripts" / name) for name in FILES] +
                   [REMOTE + ":" + REMOTE_DIR + "/"], cwd=str(ROOT), check=True)
    library_present = subprocess.run(
        SSH + ["test -d %s/cm_interface/.git" % REMOTE_DIR],
        cwd=str(ROOT)).returncode == 0
    if not library_present:
        subprocess.run(SCP + ["-r", str(CM_INTERFACE),
                              REMOTE + ":" + REMOTE_DIR + "/"],
                       cwd=str(ROOT), check=True)
    verify_remote()
    print("ALL_LINKS_V2_TIMED_DEPLOY_VERIFIED " + REMOTE_DIR)


def run_remote(script, arguments, evidence_tag):
    verify_remote()
    evidence = ROOT / "build" / "diagnostic_archive" / (
        "all-links-v2-timed-%s-%d.log" % (evidence_tag, int(time.time() * 1000000)))
    command = "cd %s && python3 -u %s %s" % (
        REMOTE_DIR, script, " ".join(shlex.quote(value) for value in arguments))
    with evidence.open("x") as stream:
        process = subprocess.Popen(SSH + [command], cwd=str(ROOT),
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT,
                                   universal_newlines=True)
        for line in iter(process.stdout.readline, ""):
            print(line, end="")
            stream.write(line)
            stream.flush()
        result = process.wait()
    print("ALL_LINKS_V2_90S_EVIDENCE " + str(evidence))
    report = None
    if script.startswith("test_all_links_v2_"):
        report = write_report(evidence, script, arguments, evidence_tag,
                              result, CM_INTERFACE_COMMIT)
    if report is not None:
        print("ALL_LINKS_V2_TIMED_REPORT " + str(report))
    if result:
        raise RuntimeError("test failed; preserve evidence and do not replay")


def status():
    run_remote("all_links_v2_timed_status.py", [], "status")


def results():
    run_remote("all_links_v2_timed_results.py", [], "results")
