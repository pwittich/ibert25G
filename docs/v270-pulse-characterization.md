# V270 lane-12 pulse characterization — 2026-09-12

**Sequence/run ID 3 passed the external-pulse diagnostic validator.** F1
remains v270 / 2.5.20 (`0x00020114`), healthy IDLE. There was one lane-12
injection request, no CPU halt, reload, optical disable, or fourth run.
This follows the [two clean baselines](v270-hardware-baselines.md); it is not
runtime link-loss qualification or a sufficient basis for detector thresholds.

## Procedure and result

Preflight confirmed the unchanged successful run-2 publication. JTAG
enumeration identified F1 as target 1, its running MicroBlaze as target 3,
and F2 as target 4. `build/pulse270-run3.tcl`, executed by XSDB on lnx4189,
connected with `-url TCP:lnx4189:3121`. Its exclusive-created log records
version `0x20114`, sequence 3, state RUN, prior completed run ID 2 and mask
`0xF000` before permitting exactly one `mwr 0x44a00060 0x1000`.

The separate Apollo operator used `milestone270_characterize.py --sequence 3
--previous-sequence 2 --expected-run-id 3 --stimulus external-pulse
--duration-ms 10000 --output run3-pulse.json`. Raw capture was saved before
validation; local offline validation passed again after copying it.

XSDB host timestamps (Unix milliseconds): write begin `1789243640015`,
write end `1789243640018`, post-read `1789243640024`. Toggle changed from
`0x00000000` to `0x00001000`, with state still RUN. The 3-ms host command
interval is **not** the TX pulse width; RTL generates one TX-clock pulse
from the toggle request. No other injection bit was written.

- Matching response/summary `0x01030401`: one deliberately error-bearing
  lane, three clean lanes, four selected, normal duration completion.
- Lane 12 published **2 RXPRBSERR-active cycles**; lanes 13–15 published zero.
  These are active-cycle counts, not exact PRBS bit-error counts.
- Native lane-12 profile: errors 2, longest consecutive run 2, first/last
  error indices 96,039,481 / 96,039,482, span 2 RX cycles. Native profiles on
  the other three lanes remained zero. Each profile elapsed 3,222,603,380 cycles.
- Every lane had 3,222,603,381 valid measurement cycles and
  257,808,270,480 tested bits, selected/locked status `0x180C`–`0x180F`, zero
  lock losses and no saturation.
- RX monitor read 322261 / 322263 kHz before/after. This is endpoint clock
  evidence, not a continuous oscilloscope measurement.
- Trace epoch 3 retained 103 events, no overflow, stable metadata/records
  across readout. FD requested/accepted/completed counts advanced 2→3, with
  cause 3, status 3, mask `0xF`: exactly one cleanup restart, no acquisition
  restart. Final PRBS controller IDLE and quad ready passed validation.

### Trace interpretation limit

The measurement trace has PRBS selections `0x55555555`. Its `error_seen`
field was already `0xF` at measurement start (raw status `0x001FFFFF`), so
this sticky management-domain field cannot distinguish the injected pulse
from earlier acquisition errors. Do not claim the trace timed this pulse.
The independent RX-local profile supplies the two-cycle event evidence.

## Power and module readback

JTAG SysMon pre/post: F1 26.0 / 26.0 C; F2 24.5 / 24.0 C. Logs are
`build/temperature-pre270-run3.log` and `build/temperature-post270-run3.log`.
Supply status fields were all zero, before and after. Page-0 Vout was
1.204345703125 / 1.20263671875 V; page-1 Vout 0.905029296875 /
0.902587890625 V. Regulator temperatures were 32.0625 C before, 31.53125 /
31.03125 C after. Raw negative currents remain unvalidated. FireFly readings
were 37–38 C; outputs remained enabled (byte 86 zero).

Read-only alarm investigation after the run:

- Identity `Samtec Inc`, part `B0425040011201`, revision `0`.
- Bytes 2–8: `00 FF 00 FF 00 00 00`; byte 86=`00`, 98=`FF`, 99=`00`,
  masks 100–102=`00`, page select 127=`00`.
- Repeated bytes 3/5 after one second remained `FF/FF`. Contiguous four-byte
  reads at byte 2 likewise returned `00ff00ff` twice; byte 6 returned
  `00000000`. Wire framing was `r FF 8 0 2 4`.
- Individual and block reads agree, with plausible identity/telemetry and
  page zero. These observations do not establish the alarm cause or rule out
  a firmware/read-path issue. No mask, CDR, page, reset or output setting was
  changed. The local JSON register map conflicts with the supplied x4 alarm
  addresses; it was not substituted for the user's bytes 3/5 interpretation.

Optical stimuli remain paused until the all-ones alarm readback is resolved
against the installed module's authoritative register map and/or MCU FireFly
read implementation. Do not reinterpret `FF/FF` as clear or reset the module
to hide it. Next request would be sequence 4 after 3 / run ID 4 if hardware
remains unchanged, but no optical request is scheduled yet.

## Evidence

Apollo originals: `/tmp/v270-diagnostic-20260912/run3-pulse.{json,log}`.
Local SHA-256:

- `build/diagnostic_archive/v270-run3-pulse.json`:
  `508fb26e86f12815714458d6de9c5022976f7f04d1bf67b9261d2abb16294218`
- `build/diagnostic_archive/v270-run3-pulse.log`:
  `8d54a61cc5d1c34b082a7379408e3eeddef1db25e2e525cabf817561bfb492ec`
- `build/v270-run3-xsdb.log`:
  `297b9987f65c64d59a7affc8d46b68e920ba54f5006a1e621cdd8f508a6ca19f`
