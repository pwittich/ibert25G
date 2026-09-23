# Four-channel FireFly live map check

## Authorized RX0 CDR bypass comparison

On 2026-09-12 the user authorized temporarily bypassing only F1_5 RX channel
0's CDR. `build/check_ff_rx0_cdr.py` executed on Apollo through SSH stdin,
confirmed part `B0425040011201` and FPGA hardware version `0x00020114`,
saved byte 98=FF, wrote FE, and verified readback. A `finally` block restored
FF and verified it. Process exit status was zero. No FPGA reload or run request
was issued. Alarm reads have read-to-clear side effects.

| Phase | Unix timestamp | Byte 98 | Managed RX clock (kHz) | LOS / CDR LOL |
| --- | ---: | --- | ---: | --- |
| Before | 1789254662.9285595 | FF | 322009 | FF / FF |
| Bypassed, first sample | 1789254664.153573 | FE | 322009 | FF / FF |
| Bypassed, second sample | 1789254665.663498 | FE | 322010 | FF / FF |
| Restored, first sample | 1789254666.8880434 | FF | 322009 | FF / FF |
| Restored, second sample | 1789254668.1048033 | FF | 322009 | FF / FF |

Restoration readback timestamp: 1789254665.8869207. Every sample had valid
clock status 0x434DA501, generated clocks 100000/325000 kHz, left x4 reference
322260–322261 kHz, and r24 reference 320637–320638 kHz. Module status byte 2,
TX disable byte 86, rate select byte 99, and alarm masks 100/102 were all zero.
In v270 r38 is managed RXUSRCLK2, not the generic reader's lf_r1_ab label.

No meaningful frequency or alarm change was observed during this bounded
comparison. Register readback proves the requested control value was stored;
it does not independently prove the module's internal CDR actually bypassed,
nor establish PRBS health. No measurement run was performed.

## Earlier read-only map check

Date: 2026-09-12. Diagnostic investigation; no new FPGA run or optical stimulus.

The supplied *Firefly Manual ECUO 25G_28G x4 Revision_1.0.pdf* confirms lower
byte 3 is LOS and byte 5 is CDR LOL. The conflicting MCU LOS display is
explained by the [MCU mapping bug](mcu-firefly4-alarm-mapping-bug.md).
This resolves the address question, not the persistent alarm condition.

Fresh direct reads through Apollo's `cm_interface` used explicit physical
F1_5/F1_6 addresses 0x28/0x29 rather than registry enumeration. The command
only read module registers; alarm reads can clear latched flags. No reset,
page/control write, FPGA programming, or measurement request was issued.

| Decimal address / meaning | F1_5 raw hex | F1_6 raw hex |
| --- | --- | --- |
| 0–2 identifier/reserved/status | 810000 | 810000 |
| 3 LOS | ff | ff |
| 5 CDR LOL | ff | ff |
| 22 temperature | 26 | 27 |
| 26–27 supply | 8110 | 808e |
| 34–37 RX optical power channels 1–2 | 3bce3c82 | 34ee3408 |
| 38–41 RX optical power channels 3–4 | 3318362e | 3976393a |
| 86 TX disable | 00 | 00 |
| 98 CDR enable | ff | ff |
| 127 upper page | 00 | 00 |

Using the manual's MSB–LSB ordering and 0.1-uW optical-power units, RX powers
are approximately 1.31–1.55 mW across these eight channels. Module temperatures
are 38/39 C, not FPGA temperatures. Supply values are 3.3040/3.2910 V.

The modules therefore report nonzero received optical power while all LOS and
CDR LOL flags read asserted. Optical power alone does not prove valid data or
CDR lock, and these latched flags are not an instantaneous link-state sample.
Status byte 2 was zero before the alarm reads; this deserves reconciliation
with interrupt behavior and masks rather than an assumption of healthy alarms.

Next investigation: reconcile persistent alarm reporting with the installed
module firmware/revision, interrupt status/masks and repeated timed reads.
Do not select integrity-detector thresholds or claim an optical-loss gate
passed from these data. Keep optical stimuli and baseline sequence 4 on hold
until the alarm inconsistency is understood or an explicit revised diagnostic
procedure is agreed. F1's last verified FPGA state remains v270 healthy IDLE
after sequence/run ID 3; this module-only check did not reverify FPGA state.
