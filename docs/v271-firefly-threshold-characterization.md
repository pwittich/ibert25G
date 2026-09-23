# V271 FireFly threshold characterization

Date: 2026-09-13. F1 remained on the already audited isolated v271 / 2.5.21
image (`0x00020115`). No FPGA programming, reset, retry, or stimulus beyond the
single described FireFly write occurred before the clean follow-up.

## Preflight

The version-matched diagnostic capture found F1 healthy and IDLE at request,
response, and run ID 4 with the clean sequence-4 publication intact. FireFly
F1_5 byte 86 was `0x00`; temperature was 38 C. Both F1AVTT/CC regulator pages
had zero status words. Required reference/generated clocks were present. The
managed RX monitor read 322.009 MHz before sequence 5, within its accepted
range. The familiar raw F1_5 byte-3/byte-5 `FF/FF` state remained and was not
treated as live LOS/CDR evidence without the timed stimulus context.

An attempted parallel diagnostic read caused two MCU-UART read failures. It
made no configuration writes. All subsequent board access was serialized and
the complete v271 preflight was repeated successfully before the run.

## Sequence 5: 250-ms channel-0 disable

The matching v271 operator committed one unique 10-second four-lane external
request, then disabled only F1_5 channel 0 through byte 86 bit 0. The write
took 4.242 ms; the measured interval from completion of the disable write to
the start of restoration was 250.280 ms; restoration took 4.217 ms. The
operator verified byte 86 returned to `0x00` in its `finally` path. Timed alarm
reads after the outage were LOS/CDR-LOL `0x11/0x11`, consistent with RX0/TX0
LOS and RX0/TX0 CDR-LOL history. A later post-test read again found byte 86
`0x00`, temperature 38 C, and the familiar readback `FF/FF`.

Sequence/run ID 5 completed normally with summary `0x01030401`:

- Lane 12 alone recorded 3,133,090,464 error-active cycles out of
  3,222,603,224 elapsed cycles, duty 0.972223.
- Its first error was cycle 89,512,760 and the error remained asserted through
  the last measurement cycle. Error span and maximum consecutive run were both
  3,133,090,464 cycles, approximately 9.72 seconds.
- Lanes 13–15 had zero error-active cycles. All four lanes had zero native lock
  losses and valid, nonsaturated profiles.
- Exactly one cause-3 cleanup restart completed. Trace epoch 5 retained 104
  events without overflow.
- RXUSRCLK2 read 322.262 MHz after capture. The profile's continuously advancing
  elapsed counter proves the RX domain resumed/continued sufficiently to record
  the run, but this test did not sample the clock during the 250-ms outage.

The corruption continuing after byte-86 restoration is a receiver/checker
reacquisition behavior, not evidence that the module output stayed disabled.
It also means output restoration must not be used as a proxy for immediate data
integrity recovery.

## Sequence 6: clean recovery control

After preserving sequence 5 and confirming byte 86 and power status, one unique
10-second clean request was issued with no FireFly writes. Sequence/run ID 6
passed with summary `0x00040401`: all lanes recorded zero errors and zero lock
losses, valid ~3.2226-billion-cycle profiles, one cleanup restart, and 103 trace
events without overflow. The managed RX monitor then read 322.260 MHz. F1
remains v271 healthy IDLE at request/response/run ID 6.

## Threshold decision and evidence

This result closes the missing longest-run evidence identified in the runtime-
integrity design review. The observed optical disturbance produced one
continuous error-active interval about 97 million times longer than the known
two-cycle injection control and about 97 times longer than the proposed
100-ms assertion interval. The first v272 candidate may therefore retain the
100-ms consecutive-error policy; a density detector is not required by the
observed hardware behavior. This establishes detection margin for this
controlled case, not the minimum detectable outage duration.

The shared-RXUSRCLK2 heartbeat detector is still separate. The optical test is
not a missing-clock test and does not claim that an individual recovered clock
stopped.

- `build/diagnostic_archive/v271-pre-seq5-firefly.json`:
  `505c2eae44c18c7fff898f4423f7453b3bdc20558f060bbd73125d4895076ce5`
- `build/diagnostic_archive/v271-run5-firefly250ms.json`:
  `ce9cb113d4abcb597018eaed6c919fb8923d5825e7ff84044569f532bef3b9f7`
- `build/diagnostic_archive/v271-run6-post-firefly-clean.json`:
  `d8f028a6eb9b111cd1914d963373ef23014447a5152a0f88172fce51b93d9c65`

All three local copies match the Apollo SHA-256 values. Both run records pass
independent offline validation with the v271 operator. Generated evidence
remains under `build/` and is not committed.
