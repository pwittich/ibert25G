# HOWTO: run FPGA link BER tests

This guide uses the repository's all-links v2 tools on a Cornell rev3
dual-VU13P blade. They perform timed, external-path PRBS31 tests at
25.78125 Gb/s. The current image is a managed-GTY design, not the vendor IBERT
GUI image; these are the command-line tools for the same kind of link BER
measurement.

Initial setup loads the audited image on both FPGAs. Subsequent tests reuse
the healthy running image: SSH to the blade, read status, run one test, and
save the results and final status. See the
[FPGA firmware block diagram](docs/fpga-firmware.md) for the architecture.

## Quick start: three-minute inter-FPGA test

After [deploying the updated scripts](#scripts-and-deployment) with clean
`cm_interface` v1.0.3, run the following directly on the blade. The versioned
directory is the persistent installation example used in this guide.
Confirm first that everything connected to the outward FireFly TXs can
safely receive PRBS31: the shared TX session activates those outputs too.

```bash
ssh cms@apollo3010-1
cd /home/cms/25G-v1.0.3
python3 -u all_links_v2_timed_status.py
```

Both endpoints must report `0x00020501`, healthy IDLE/session-off
`0x00100000`, and valid required clocks. The runner automatically discovers
the sequence/run counters under the MCU lock; there are no counters to copy
into the ordinary test command.

```bash
mkdir -p "$HOME/25G-test-logs"
log="$HOME/25G-test-logs/inter-fpga-180s-$(date -u +%Y%m%dT%H%M%SZ).log"
set -o pipefail
python3 -u test_all_links_v2_inter_fpga.py \
    --duration-seconds 180 \
    --acknowledge-all-firefly-tx \
    2>&1 | tee "$log"
test_status=${PIPESTATUS[0]}
echo "Test exit status: $test_status"

# After the test process exits, verify both TX sessions are off.
python3 -u all_links_v2_timed_status.py 2>&1 | tee "${log%.log}.status.log"
```

Require exit status zero and the `PASS INTER_FPGA ...` marker. Inspect any
failure before starting another test. An invocation without explicit state
guards always requests a new measurement; repeating it does not resume a
disconnected run. The optional guards are documented below for automation.

## Recorded results

The 2026-10-27 180-second bidirectional test on Apollo 3010 used the exact
audited all-links v2 image and clean `cm_interface` v1.0.3:

| Observable | F1 receivers | F2 receivers |
| --- | --- | --- |
| Fitted inter-FPGA lanes passed | 54 / 54 | 54 / 54 |
| PRBS errors | 0 | 0 |
| Native lock losses | 0 | 0 |
| Valid tested bits per lane | approximately 4.64055e12 | approximately 4.64055e12 |
| Final state | Healthy IDLE; TX session off | Healthy IDLE; TX session off |

For each tested lane, zero observed errors corresponds to an approximate
one-sided 95% upper BER bound of `-ln(0.05)/N = 6.46e-13`, under a stationary
independent rare-error model. This is a finite-duration direct-link result;
FireFly receivers were not measured in that run. The previous optical-loopback
history still includes repeatable errors on four F1 lanes.

The [immutable report](build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.report.md)
and [hardware record](docs/all-links-v2-inter-fpga-hardware-gate.md) preserve
the exact counters, telemetry and earlier failures. The later automatic
sequence-discovery change has focused offline coverage; this table records
the actual completed hardware run, not a new run of the changed interface.

## Which quads can I test?

| Link class | Quads | Global receive lanes | Current command-line selection |
| --- | --- | --- | --- |
| FireFly optical links | q121–q134 | 0–55 | One quad, an inclusive range, or comma-separated combinations |
| Direct FPGA-to-FPGA links | q221–q234 | 56–111 | All 54 fitted receivers at each endpoint |

Both test scripts operate on **F1 and F2 together**. FireFly selection applies
the same quad set to both sites. The direct test uses different fitted-lane
masks for the two sites: it omits F1 globals70/71 and F2 globals96/97.
The 10-Gb/s AXI C2C lanes are excluded.

FireFly selector examples:

```text
q121                  one quad: four receive lanes per FPGA
q121-q124             four quads: sixteen receive lanes per FPGA
q121,q124,q130        three nonadjacent quads
q121-q123,q130-q134   two ranges
```

The inter-FPGA script does **not** accept a selector such as `q221-q223`.
Arbitrary direct-quad subsets, individual lane selection, different FireFly
sets on F1/F2, and mixed FireFly/direct selections need a CLI extension.
The firmware supports a receive-lane mask, but the existing operator scripts
expose only the selections in the table above. Do not change the frozen
fitted-lane masks just to select a different test.

See [README.md](README.md) for the physical lane and connector mapping.
Check the actual partner wiring; matching quad numbers are not a statement
that those two quads connect to each other.

## Current limitation: all TXs run, selected RXs are measured

Every test starts a TX session with all **112 transmitters on each FPGA**:
56 FireFly TXs and 56 direct inter-FPGA TXs. A receive selection changes which
receivers are measured, not which transmitters send PRBS31.

For example, a direct-link-only test also sends PRBS31 out through every
FireFly optical TX. A `q121` FireFly test measures four receivers per FPGA,
while all 112 TXs on each FPGA still send PRBS31.

Before starting either test, confirm that equipment connected to **all**
outward optical outputs can safely receive PRBS31. Disconnected outputs are
fine. The acknowledgement options in the commands below express that check.

Only selected quads participate in acquisition-ready and capture-done
measurement reductions. Global readiness, faults, idle/reset, and TX-session
application barriers still involve all 28 managed quads. A receive subset
therefore does not isolate every possible fault in an unselected quad.

The session lease is the measurement duration plus 60 seconds. The scripts
attempt an explicit normal stop on both sites; the lease bounds TX activity
if normal cleanup cannot complete. Session-off means the PRBS31 session has
stopped, not that the optical modules have been physically disabled.

## Prerequisites

- Both FPGAs must run the audited all-links v2 image, firmware/hardware
  identity `0x00020501`. The exact compressed BIT is
  [gt_test_all_links_v2_timing_hardened_control_boundary_fix.bit](build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/artifacts/gt_test_all_links_v2_timing_hardened_control_boundary_fix.bit),
  SHA-256 `163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f`.
  It includes the MicroBlaze program; Hardware Manager can load this BIT
  without a separate ELF download. Programming is a separate operation that
  replaces live state; a new test does not require reprogramming.
- The blade must have Python 3.6 or later, the dependencies used by
  `cm_interface`, and access to the MCU UART at `/dev/ttyUL4`.
- This guide uses clean `cm_interface` **v1.0.3**, commit
  `64260cf23b01c9da987feda1fbf51567240c2c71`. This version passed both read-only
  checks and a 180-second bidirectional direct-link test on Apollo 3010 on
  2026-10-27. Other blades still need their own identity, clock, and wiring
  checks.
- Direct links need their fitted board connections. Selected FireFly RXs
  need physical optical loopbacks or matching external PRBS31 partners.
  On the recorded 3010 bench, q121–q124 self-loop independently on each FPGA;
  they are not F1-to-F2 optical links. Do not assume that wiring elsewhere.
- Serialize MCU/UART access. During a test, let its process own the UART;
  avoid other status, telemetry, or control programs. The supplied scripts
  share `/tmp/all-links-v2-90s-mcu.lock`, but unrelated tools may not use it.

If using the repository programmer, choose `all_links_v2_f1` or
`all_links_v2_f2` with [board_program.py](scripts/board_program.py). It checks
the artifact hashes and JTAG topology. Each blade has two VU13Ps. If XSDB
lists devices from another blade, resolve the stale `hw_server` connection
before programming; do not relax the topology check.

## Scripts and deployment

All test and status scripts below are maintained in this repository's
[`scripts/`](scripts/) directory. The files needed on the blade are:

```text
all_links_v2_timed_contract.py
all_links_v2_timed_common.py
milestone3_12hour_external_soak.py
all_links_v2_timed_status.py
all_links_v2_timed_results.py
test_all_links_v2_inter_fpga.py
test_all_links_v2_firefly_loopback.py
cm_interface/                         clean v1.0.3 checkout, including .git
```

`milestone3_12hour_external_soak.py` supplies shared mailbox helpers here;
copying/importing it does not start its historical soak procedure.

The v1.0.3 bundle used on 3010 is already at:

```text
/tmp/all-links-v2-status-v103-20261027
```

That original bundle predates the automatic sequence/run discovery described
below. Copy the updated runtime scripts before using the simplified commands;
the persistent installation example below includes them.

That directory is temporary. For a persistent installation, the following
example copies the same repository scripts into a **new** versioned directory.
Run it on a host with this repository and the clean v1.0.3 library checkout
available, such as lnx4189. Substitute the intended blade hostname. When
already on lnx4189, SSH directly to the blade; no lnx4189 jump is needed.

```bash
# From the root of this repository, on the workstation:
git -C /nfs/cms/tracktrigger/wittich/int_test/cm_interface status --porcelain
git -C /nfs/cms/tracktrigger/wittich/int_test/cm_interface describe --tags --exact-match HEAD
git -C /nfs/cms/tracktrigger/wittich/int_test/cm_interface rev-parse HEAD

# Require empty status, v1.0.3, and the exact commit listed above.
# mkdir deliberately fails if this installation directory already exists.
ssh cms@apollo3010-1 'mkdir /home/cms/25G-v1.0.3'
```

After `mkdir` succeeds, copy the runtime and library. If the directory already
exists, inspect and verify it before deciding to reuse it; do not overwrite
an unknown installation.

```bash
scp scripts/all_links_v2_timed_contract.py \
    scripts/all_links_v2_timed_common.py \
    scripts/milestone3_12hour_external_soak.py \
    scripts/all_links_v2_timed_status.py \
    scripts/all_links_v2_timed_results.py \
    scripts/test_all_links_v2_inter_fpga.py \
    scripts/test_all_links_v2_firefly_loopback.py \
    cms@apollo3010-1:/home/cms/25G-v1.0.3/

scp -r /nfs/cms/tracktrigger/wittich/int_test/cm_interface \
    cms@apollo3010-1:/home/cms/25G-v1.0.3/

# Make and copy a runtime hash manifest, with filenames relative to scripts/.
(
    cd scripts || exit
    sha256sum all_links_v2_timed_contract.py all_links_v2_timed_common.py \
        milestone3_12hour_external_soak.py all_links_v2_timed_status.py \
        all_links_v2_timed_results.py test_all_links_v2_inter_fpga.py \
        test_all_links_v2_firefly_loopback.py
) > /tmp/all-links-v2-runtime.sha256
scp /tmp/all-links-v2-runtime.sha256 \
    cms@apollo3010-1:/home/cms/25G-v1.0.3/runtime.sha256
```

The repository's `board_all_links_v2_*.py` workstation wrappers currently pin
v1.0.0 and `/home/cms/25G`, with a jump through lnx4189. They have not been
migrated to the direct-on-blade v1.0.3 workflow in this guide. The 2026-10-27
v1.0.3 measurement used a separate archived wrapper; see the
[hardware record](docs/all-links-v2-inter-fpga-hardware-gate.md).

## 1. SSH to the blade and verify the bundle

```bash
ssh cms@apollo3010-1
cd /home/cms/25G-v1.0.3
# Or, for the existing temporary 3010 installation:
# cd /tmp/all-links-v2-status-v103-20261027

git -C cm_interface status --porcelain
git -C cm_interface describe --tags --exact-match HEAD
git -C cm_interface rev-parse HEAD
```

Require empty status output, tag `v1.0.3`, and the commit listed above.
For the persistent installation with a manifest, also run:

```bash
sha256sum -c runtime.sha256
```

Do not proceed with modified scripts or an unexpected library version.
Directly invoked test scripts check the firmware ABI, but they do not verify
their own source hashes or the library's Git revision for you.

## 2. Read status

```bash
python3 -u all_links_v2_timed_status.py
```

The script checks both FPGA identities and required clocks, then prints board
power and temperatures. Each site must have:

- `fw=0x00020501 hw=0x00020501`;
- `state=0x00100000`: healthy IDLE with the TX session off;
- matching `request` and `response` values;
- valid clock-monitor status and required fabric/GT reference frequencies.

You do not need to copy sequence numbers or run IDs into the test command.
The runner acquires the MCU lock, reads a stable idle snapshot at each site,
and logs the sequence/run values it will use. It checks that state again
before starting TX sessions and checks each sequence before submitting the
next request. Busy, faulty, unacknowledged, changing, or unexpected-version
endpoints are rejected before starting a test. F1 and F2 may have different
sequence/run values.

For example, this status is ready for a new test:

```text
STATUS site=F1 fw=0x00020501 hw=0x00020501 state=0x00100000 request=3 response=3 code=0x00000000 run=1 summary=0x00363601
```

Choose a duration and prepare logging:

```bash
duration=180
mkdir -p "$HOME/25G-test-logs"
set -o pipefail
```

Both runners accept `--duration-seconds` from 1 through 86340; the default is
90. A value of 180 gives a three-minute hardware-timed measurement. Setup,
acquisition, telemetry, and cleanup add to the total command runtime.

If a generic interface does not acknowledge, the v1.0.3 MCU API also exposes
`registry.mcu.read_runtime().fpga_done` (runtime page `0x06`, offset `0x15`).
This is a raw **active-low** bitmap: bit 0 is F1 and bit 1 is F2. Thus `0x00`
means both configured, `0x02` means F1 configured/F2 unconfigured, `0x01`
means F2 configured/F1 unconfigured, and `0x03` means neither configured.
DONE does not identify the loaded image; still verify the firmware/hardware
version through the generic interface.

## 3a. Test all fitted direct inter-FPGA links

Run this **instead of** the FireFly example in the next section:

```bash
log="$HOME/25G-test-logs/inter-fpga-${duration}s-$(date -u +%Y%m%dT%H%M%SZ).log"

python3 -u test_all_links_v2_inter_fpga.py \
    --duration-seconds "$duration" \
    --acknowledge-all-firefly-tx \
    2>&1 | tee "$log"
test_status=${PIPESTATUS[0]}
echo "Test exit status: $test_status"
```

This measures both directions on all 54 fitted receivers per FPGA. The
acknowledgement confirms that PRBS31 on all outward FireFly TXs is safe.

The successful completion marker for a 180-second test is:

```text
PASS INTER_FPGA duration_seconds=180 fitted_rx_lanes_per_endpoint=54 errors=0
```

## 3b. Test selected FireFly optical-loopback quads

Use a physically connected receive set. For example:

```bash
quads=q121-q124
# Other valid examples: q121 or q121,q124,q130 or q121-q123,q130-q134
log="$HOME/25G-test-logs/firefly-$(date -u +%Y%m%dT%H%M%SZ).log"

python3 -u test_all_links_v2_firefly_loopback.py "$quads" \
    --duration-seconds "$duration" \
    --acknowledge-all-managed-tx \
    2>&1 | tee "$log"
test_status=${PIPESTATUS[0]}
echo "Test exit status: $test_status"
```

Only q121–q134 are accepted. Each selected quad adds all four receivers at
both sites. This uses the physical optical path (`LOOPBACK=000`), not internal
PMA loopback. A selected disconnected receiver fails acquisition or validation.
Look for a `PASS FIREFLY_EXTERNAL_LOOPBACK ...` completion marker and zero exit
status.

Each invocation requests a new measurement from the current healthy idle
state. After each completed test, inspect its result and final status before
deciding to start another.

### Optional state guards for automation

For a procedure that must start from a particular state, all four original
flags remain available. Supply them together, using expected **current**
values, not incremented values:

```bash
python3 -u test_all_links_v2_inter_fpga.py \
    --duration-seconds 180 --acknowledge-all-firefly-tx \
    --f1-sequence 3 --f1-run 1 --f2-sequence 3 --f2-run 1
```

This command aborts if either endpoint differs from that expected state.
Reusing the same explicitly guarded command after it consumes those values
fails its guard. Ordinary interactive commands can omit these flags entirely.

## 4. Interpret the result and confirm cleanup

Each selected lane must be locked, report zero PRBS errors and zero native
lock losses, and have a valid tested-bit denominator for the requested
duration. The scripts validate these conditions and print individual
`RECORD` lines. A clean three-minute measurement is about 4.64e12 bits per
lane. It establishes the result for that interval, not permanent error-free
operation.

Power, FPGA diode temperatures, all LGA80D temperatures, and all physical
FireFly module temperatures are sampled before, near one-third/two-thirds,
and after the measurement. There is no configured numerical thermal/power
trip threshold in this procedure; missing or invalid required telemetry
fails the run. An immediate post-stop ADC sample can still reflect earlier
activity.

After the test process has exited, save a final status snapshot:

```bash
python3 -u all_links_v2_timed_status.py 2>&1 | tee "${log%.log}.status.log"
```

Require healthy IDLE/session-off on both sites. On a normal successful run,
each site's sequence advances by three (session start, measurement, session
stop), and its published run advances by one. For example, predecessor
sequence 3/run 1 normally ends at sequence/ack 6/run 2. Read the actual state;
do not infer it after a failure.

To inspect the retained **direct-link** publication and platform diagnostics:

```bash
python3 -u all_links_v2_timed_results.py
```

That result-dump script enumerates the fixed direct receive masks. After a
FireFly test, use the test log's `RECORD` lines for the selected optical lanes;
the direct-result dump is not a general FireFly result viewer.

## Failure, disconnects, and evidence

If the process fails, times out, or loses SSH, preserve the log and inspect
status once the test process has stopped owning the MCU. Do not automatically
repeat the command, reset/reprogram the FPGAs, or assume the sequence is
unchanged. With automatic discovery, rerunning the command after completion
would start a **new test**, not resume the previous one. A disconnect does not
prove that the remote process has stopped.
The bounded session lease and normal cleanup limit TX activity; verify the
final sessions-off state before a new test.

The direct-on-blade commands above save raw logs through `tee`. Keep the
command, logged `PREDECESSOR` values, blade identity/wiring, runtime hashes, library
revision, and final status with the log. The workstation wrappers additionally
create an immutable Markdown report automatically; the direct commands do not.

See the [timed-test contract](docs/all-links-v2-timed-tests.md) and
[inter-FPGA hardware record](docs/all-links-v2-inter-fpga-hardware-gate.md) for
the protocol, artifact hashes, and recorded results. The guide itself does
not authorize an additional hardware run.
