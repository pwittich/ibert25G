# Diagnostic command approvals

## V275 fixed qualification-candidate helpers

The active narrow rule allows `python3 scripts/board_v275.py` only with
`deploy`, `clean1`, or `clean2`. It fixes the exact v275 identity, predecessor
sequence, run ID, 10-second duration, clean stimulus, hosts, paths, and
non-overwriting evidence files. Deployment hash-verifies the complete reviewed
Apollo bundle. The completed runs used this rule without retry. It does not
authorize programming, reset, arbitrary stimuli, or a later long soak.

The separate active narrow rule for `python3 scripts/board_program.py v275`
permits only the fixed F1 programmer for the audited v275 artifact. The Tcl
helper pins bitstream SHA-256
`92cf91bbfd2214f0349cb6155c527eddf198268a03585d25fbe715e84d90d08e`
and matching ELF SHA-256
`b72ac12cfa79d4e43d3b119eff74f1da7fa8b77b925a31618caa4576f5a58adf`.
Task authorization remains required for every reload.

The active separate narrow rule for `python3 scripts/board_v275_soak.py`
covers only `deploy`, `start`, `status`, and `results`. The helper fixes F1,
identity `0x00020119`, unique sequence 3 after response/run 2, external PRBS31,
lanes 12-15, 43,200,000 ms, remote paths, and non-overwriting local logs. Its
`start` operation has already been consumed and must not be invoked again. The
initial post-start assertion incorrectly expected the published run ID to
advance on RUN entry; it exited nonzero after the sequence had successfully
started. No retry occurred. The corrected bundle was tested, redeployed with
hash verification, and read-only `status` confirmed sequence 3 RUN with the
prior run-2 bank still published. Only `status` and eventual `results` remain
authorized for this active run.

## V274 fixed diagnostic launcher

The active narrow rule allows `python3 scripts/board_v274.py` with only
`deploy`, `clean1`, and `heartbeat2`. The launcher fixes both sequences,
predecessor states, run IDs, duration, hosts, paths, and non-overwriting
evidence names. Deployment hash-verifies its reviewed Apollo bundle. The
heartbeat watcher must acknowledge exact v274 IDLE sequence/run 1 before the
host submits sequence 2; it writes only `0x00008000` to fixed AXI address
`0x44a00060` once to suppress the monitor heartbeat and once to restore it.
After the first write, restoration is unconditional. It never halts/resets the
MicroBlaze or programs the FPGA. The completed gate used this rule; permission
does not authorize a later run or a new stimulus.

The separate active narrow rule for `python3 scripts/board_program.py v274`
permits the fixed F1 programmer for the audited v274 artifact. The Tcl helper
pins bitstream SHA-256
`0dd18f901c69f43e51a80aeb5e9e0727b8842e9aa98f69565af3ee07f48ad80a`
and matching ELF SHA-256
`dc20fc8b37d19d393f031786df21313df5aee9dc82f21ef0c1102ee5e5b1d7b0`.
Task authorization remains required for every reload.

## V273 fixed diagnostic launcher

The active narrow rule allows `python3 scripts/board_v273.py` with only the
launcher's `deploy`, `clean1`, `clean2`, `pulse4`, and `firefly5` choices.
`deploy` copies a fixed reviewed operator bundle to
`/tmp/v273-diagnostic-20260913` and verifies every remote SHA-256. Every run
choice has fixed identity, sequence, prior sequence, run ID, duration, remote
location, and non-overwriting local evidence destination. `pulse4` also pins
the single AXI injection write and waits for the watcher-arm acknowledgement
before submitting the request. `firefly5` pins F1_5 channel 0, 250 ms, and
restores byte 86. None performs programming, reset, or retry. The launcher
retrieves raw JSON even when validation fails. As with
the other Python launchers, this permission trusts the reviewed mutable script
and dependencies rather than enforcing their content hashes.

The separate active narrow rule for `python3 scripts/board_program.py v273`
permits execution of the fixed F1 programmer; task authorization is still
required for every reload. The Tcl helper pins v273 bitstream SHA-256
`84a2d4db34f8ac4437dbec6f89fb2931f76f663a1846ba5b1e7d2075b08cfedf`
and matching ELF SHA-256
`e32976fabe1e7834fc34c14db21829b25741386278663869bb544c4721beb62b`.

## Separate programming helper

User authorized and installed `/home/wittich/.codex/rules/board-program.rules`
for the separate `scripts/board_program.py` launcher, with only `v270` and
`golden` image choices. Use the absolute local path, without shell wrappers or
pipes. Three offline tests and installed-rule matching passed. This does not
extend the diagnostic helper's privileges.

The programmer uses XSDB on lnx4189, fixes F1 as target 1 after verifying a
two-xcvu13p listing, checks image hashes (and v270's matching ELF), and takes a
nonblocking remote lock against other instances of this helper. It does not
protect against unrelated legacy tools or prove board identity by silicon DNA;
preflight chain review, power/temperature checks and evidence preservation
remain required. No arbitrary target, Tcl path, remote command or image is
accepted. The golden choice is the specifically authorized historical
uncompressed artifact; new builds still require compression.

The interrupted legacy v270 reload had no surviving batch process; subsequent
mailbox read had zero version words, consistent with golden rather than v270.
An unrelated interactive XSDB session was left untouched. The new helper is
used for the next explicit reload, not a silent retry of a failed test.

Installed with user approval on 2026-09-12 at
`/home/wittich/.codex/rules/board-diagnostics.rules`. Existing user rules are
unchanged. Installed-file policy checks allow `clocks` and do not match
`program`. Restart Codex to load manually added rules; prompt reduction in a
fresh session has not yet been verified.

## Stable commands

Run locally, using this exact absolute script path for policy matching:

```sh
python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py clocks
python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py modules
python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py results
python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py temperatures
```

Append `--dry-run` to inspect without connecting. Unknown operations and extra
arguments are rejected. The wrapper fixes host, SSH option ordering, device and
commands. It streams the local reviewed clock/module scripts itself, avoiding
changing shell-redirection strings in each approval. It accepts no arbitrary
Python, Tcl, remote paths, or register addresses. No payload is uploaded as a
persistent remote file.

Clocks use the existing 37-word direct-kHz reader; r38's generic label needs
interpretation against the loaded image (managed RXUSRCLK2 in v270). Modules
reads F1AVTT/CC and explicit physical F1_5/F1_6 devices. Module reads can clear
latched alarms. Results uses the existing Apollo v270 diagnostic bundle and
changes only the lane selector; coordinate with any other selector readers.
It dumps results, not acceptance criteria, and must be reconsidered when the
loaded image changes. Temperatures uses JTAG SysMon for both FPGAs, not module
temperatures. No programming, reset, fault stimulus or run launcher is included.

## Proposed rule and migration

Review `docs/board-diagnostics.rules.proposed` and the launcher/dependencies.
The reviewed rule is now installed in the user rules directory; restart Codex
to load it. The proposal copy remains outside active configuration for reference.
It permits only these four launcher operations, not generic Python or SSH.
Because scripts are mutable, this is trust in reviewed scripts and their
dependencies, not a content-hash security boundary. Review future changes.

Existing `~/.codex/rules/vivado.rules` should be preserved for the user's
previously approved build/simulation workflow. The existing `default.rules`
contains broad host SSH and SCP allows as well as one-off shell-string allows.
Adding this proposal does NOT revoke those old permissions or guarantee
hardware-changing commands prompt. A separate reviewed cleanup must remove
overlapping broad/obsolete allows if a narrower enforced boundary is desired.
Do not remove all of default.rules: it includes unrelated user decisions.
Likewise, the existing Vivado/XSDB allows can cover hardware-changing scripts;
task authorization still matters even when an execution rule allows a command.

For now, SCP remains separately approved with explicit source/destination and
no-overwrite checks; unrestricted file transfer is not included in the new
diagnostic rule. Test launches, FPGA programming and FireFly control changes
remain separate workflows, not hidden inside a diagnostic helper.

Official reference: https://developers.openai.com/codex/rules — rules compare
argument prefixes; shell redirection/complex syntax may instead be evaluated
as one shell invocation. Use `codex execpolicy check` before installation.
