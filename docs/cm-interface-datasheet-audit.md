# cm_interface datasheet audit — 2026-09-16

## Scope and result

Read-only source/datasheet review requested by the user. **No hardware was accessed, no commands were sent to the MCU, and no cm_interface source or configuration was changed.** The report identifies confirmed errors and separates unsupported claims and coverage gaps. It is not a certification that every undocumented field or board-specific route is correct.

Source checkout: `/nfs/cms/tracktrigger/wittich/int_test/cm_interface`, clean at Git commit `80401661e520d177fb8a243cfd8ef75137aed481`. Its AGENTS.md was read. Source paths/line numbers below are relative to that checkout, not this FPGA repository. The JSON maps are documentation, not runtime-loaded register definitions (`README.md:245`); their wrong write recipes remain hazardous to operators and future generated tooling.

The requested `/nfs/cms/tracktrigger/wittich/docs` directory **does not exist on this host**. Matching manufacturer documents were found under `/nfs/cms/tracktrigger/wittich/datasheets` and used instead. No web substitute was used. Page numbers are printed document pages; table identifiers are the preferred locator.

### Sources and coverage

| Key | Manufacturer document in `datasheets/` | Coverage |
|---|---|---|
| X12 | `ECUO 25G x12 Rev 4 Data Sheet.pdf` | TX/RX lower and upper maps, control masks, monitoring, channel ordering; current standard-x12 findings apply specifically to Rev. 4. |
| X4 | `Firefly Manual ECUO 25G_28G x4 Revision_1.0.pdf` | Section 13, Tables 27–53, printed pp. 52 onward; compared with Firefly4 and JSON. |
| CERN | `CERN_Back_End_x12_FireFly_User_Manual (1).pdf`, Rev. 1.0, September 2019 | Separate TX/RX maps, Tables 22–53. |
| SI | `si5395-94-92-family.pdf`, reference manual Rev. 1.3, December 9, 2021 | Python API, listed JSON controls, readiness, programming sequence, Si5395 section 16; Si5394/92 are not claimed supported by the Python class. |
| LGA | `LGA80D_40A_dual_AppNote.pdf`, Rev. 06.19.20 #2.6 | PMBus summary pp. 22–25 and detailed command descriptions; Python telemetry and JSON. |

Other inventoried PDFs: standard x12 Rev. 2/3, x12 Revision_1.0, 14G x12 v05, x12 28G D02, Si5395 A datasheet, ZL8802, 24CS512 EEPROM, fiber-polarity guide. These are not interchangeable with the reviewed profiles; alternate FireFly revisions were inventoried but not exhaustively diffed. There are no EEPROM/ZL8802 device classes to certify here. MCU/FPGA are firmware-owned protocols, not manufacturer register maps; their existing tests/maps were inspected for scope, not requalified against unavailable deployed firmware. Physical slot indices require the MCU board map, not a FireFly datasheet.

Severity: **High** = wrong control target, incomplete safety-relevant action, or false readiness; **Medium** = misleading telemetry/status/configuration documentation; **Low** = metadata or omitted capability. Unless explicitly marked otherwise, the findings below are directly supported by source plus the cited manufacturer table (high confidence).

## A. Standard twelve-channel FireFly

| ID / severity | Source location | Actual error, datasheet requirement, impact and correction |
|---|---|---|
| F01 High | `device/firefly.py:209`; `registers/firefly12.json:20` | `RX_DISABLE=0x36` addresses electrical **output** disable, not receiver-channel disable. X12 Tables 32/40/41 (pp. 27/30) put channel disable at bytes 52–53 (`0x34–35`), output disable at 54–55 (`0x36–37`). Correct the channel constant and preserve all other/reserved mask bits. |
| F02 High | `device/firefly.py:210`; `registers/firefly12.json:21` | `RX_OUTPUT_DISABLE=0x38` targets reserved bytes 56–57. Correct to `0x36`, width two; a successful bus ACK would not prove the requested output was disabled. |
| F03 High | `device/firefly.py:141`, `:145`, `:218`, `:222` | Both standard TX/RX `disable_cdr()` implementations read/write only byte 75 and silently ignore arguments 9–12. Their documented default “all 12” changes only eight channels. X12 Tables 22/45 specify bytes 74–75 (`0x4A–4B`), with the high four channels in byte 74 low nibble. Use a two-byte, big-endian mask preserving reserved bits, validate every channel before any transaction, and explicitly distinguish API 1–12 from datasheet 0–11 numbering. |
| F04 Medium | `device/firefly.py:142`, `:170`, `:219`, `:235` | CDR loss-of-lock status reads only byte 21, omitting channels 8–11 in byte 20. X12 Tables 17/39 require bytes 20–21. Return a twelve-bit mask and document latched/read effects. TX `channels` parameter is also ignored. |
| F05 High | `device/firefly.py:143`, `:220` | `CDR_LOL_MASK=0x6D` names only the second byte. A caller treating it as a two-byte base reaches reserved byte 110 and misses channels 8–11. Tables 27/50 require bytes 108–109 (`0x6C–6D`). Define the full field base/width explicitly. |
| F06 Medium | `device/firefly.py:22`, `:90`; `registers/firefly12.json:37` | Rev. 4 Tables 28/51 declare upper-page-0 bytes 133–170 reserved, so the inherited vendor-name read at 152–161 is not valid for this revision. It is valid in the CERN map. Make vendor-name capability variant/revision-specific; retain valid part/serial addresses 171/189. Do not interpret reserved bytes as identity. |
| F07 Medium | `device/firefly.py:14`, `:77`, `:138`, `:215`; `registers/firefly12.json:30` | EEPROM revision at byte 110 is reserved in X12 Rev. 4 Tables 10/32. It exists in CERN Tables 22/37. Restrict this property to profiles actually defining it, rather than returning a bogus revision. |
| F08 Medium | `registers/firefly12.json:10` | Summary bits incorrectly mark both bits 7–6 and 4–2 reserved. TX Table 12 defines bit 7 as TX LOS summary; RX Table 34 defines bit 6 as LOS and bit 2 as low-power summary. Split TX/RX maps and annotate initialization bit 0 as cleared on read. |
| F09 Medium | `registers/firefly12.json:25`, `:26` | Alarm masks say default `0x01=masked`; Tables 25/26/48/49 use high/low bits 7/6 and default zero. Bit 0 is reserved. Document masks `0x80`/`0x40`, preserve unrelated bits. |
| F10 Medium | `registers/firefly12.json:60` | RX power is described as “dBm scaled.” X12 Table 52 (p. 35) specifies unsigned, big-endian 0.1 µW/count, descending channels: 206–207=Rx11 through 228–229=Rx00 on page 1. Add the actual field map and units; derive dBm separately if desired. No Python RSSI decoder was found to blame for the user's MCU CLI reversal. |
| F11 Low | `registers/firefly12.json:22`, `:43`, `:50` | Output-amplitude prose says twelve bytes for x12, although width six is correct: Table 43 packs two channel nibbles per byte. Temperature-high default is 85°C (`0x55`), not 80°C (`0x50`), Tables 29/52. Secondary TWI-address default is `0xFF`, not `0xA0`, Tables 30/53. Correct these independently. |
| F12 Medium | `device/firefly.py:255`, `:266`; `CDR_CONTROL_SUMMARY.md:11` | `Firefly12.disable_cdr()` is an unconditional `pass` despite documentation claiming working CDR control. Standard x12 uses distinct TX/RX devices; invented `TX=0x10`, `RX=0x20` are not a combined register-space selector. Deprecate this ambiguous alias or raise `NotImplementedError` until implemented with explicitly routed endpoints. |

## B. Four-channel FireFly: inherited API and copied JSON

**F13 Medium — inherited telemetry uses the wrong family map.** `device/firefly.py:55`, `:67`, `:73`, `:77`, `:81`, `:85` are inherited by `Firefly4` without overrides. X4 Table 27 (p. 52) establishes:

| Property / definition | Current address | Correct x4 meaning/address |
|---|---|---|
| `status_summary` | `0x06` | This is temperature alarms, not a summary byte; no x12-style summary defined. |
| `temperature_alarm` | `0x11` | Reserved; actual temperature alarms at `0x06`, including warning bits. |
| `supply_voltage_alarm` | `0x12` | Reserved; actual combined VCC3.3/VCC1.8 alarms at `0x07`. |
| `elapsed_time_hours` | `0x26–27` | Rx3 optical-power bytes, not lifetime; actual elapsed time `0x13–14`. |
| `firmware_version` / `eeprom_revision` | `0x6F–71` / `0x6E` | Reserved in this x4 map; mark unsupported. |
| `Firefly4.Reg.STATUS`, `print_status()` | `0x08` (`firefly.py:305`, `:377`) | Reserved; actual status at `0x02`. Inherited `.status` already reads the correct byte. |

Correct by variant-specific properties, not changing x12 common constants globally. Existing temperature at `0x16` and supply voltage at `0x1A–1B` are correct.

**F14 High — `registers/firefly4.json` is largely an x12 map under an x4 label.** The following entries are confirmed wrong against X4 Tables 27–52; entries naming reserved writes must not be used:

| JSON line/key | Current | Required x4 replacement |
|---|---|---|
| 10 `STATUS_SUMMARY` | `0x06` summary | Temperature alarm byte; remove nonexistent summary. |
| 11 `TX_FAULT_LATCH` | `0x09` | `0x04` (Table 30); current location is power alarms. |
| 12/13 temperature/VCC alarm | `0x11`/`0x12` | `0x06`/`0x07` (Tables 32/33); include all warning/supply fields. |
| 16 elapsed time | `0x26`, two bytes | `0x13`, two bytes. |
| 17 reset | `0x33` | Reserved; no software-reset register defined here. |
| 18 TX disable | `0x34` | `0x56` (byte 86, Table 35). Python class already has this correct. |
| 19 polarity | lower `0x3A` | Page 3 byte 226 (`0x03E2`), Table 46; shared TX/RX packed fields. |
| 20 RX disable | lower `0x36` | Reserved; no matching channel-disable control defined. Do not substitute output disable without renaming semantics. |
| 21 RX output disable | lower `0x38` | Page 3 byte 241 (`0x03F1`), Table 51. |
| 22 RX amplitude | lower `0x3E`, one byte | Page 3 bytes 238–239 (`0x03EE–EF`), Table 49; packed fields, global-amplitude caveat in manufacturer text. |
| 23 RX de-emphasis | lower `0x4D`, one byte | Page 3 bytes 236–237 (`0x03EC–ED`), Table 48. |
| 24/25/26 fault/temp/VCC masks | `0x61`/`0x69`/`0x6A` | `0x65`/`0x67`/`0x68`, Tables 39/41/42. |
| 27 RX LOS latch | `0x07`, low nibble | `0x03`; combined TX/RX LOS, Table 29. |
| 28 LOS mask | `0x5F` | `0x64`; combined TX/RX LOS mask, Table 38. |
| 29/30 firmware/EEPROM revisions | `0x6F`/`0x6E` | Reserved; remove unsupported claims. |
| 36 maximum temperature | page 0 `0x84` | Page 0 byte 190 (`0xBE`), Table 43. |
| 42–47 alarm thresholds | page 1 | Page 3, Table 45; temperature high `0x55` (85°C), not 80°C. Manufacturer prose says RO but table says R/W: preserve this source ambiguity rather than invent write permission. |
| 57 amplitude-table name | `tx_output_amplitude_table` | Values shown are **RX electrical output** amplitude values from Table 49. Rename. |

**F15 Medium — invalid channel input can affect the wrong x4 direction.** `device/firefly.py:345–351` checks only `ch <= 4`. Calling `disable_cdr([0], tx=True, rx=False)` clears bit 3, which is **Rx4**, not a TX bit (X4 Table 36). With RX enabled it raises a negative-shift exception after the read. Validate integer channels 1–4 before any transaction; reject zero/negative/out-of-range values instead of ignoring them. `get_cdr_status(channels=...)` also ignores its filter argument; remove or implement that argument.

**F16 Low — serial capability omitted rather than located correctly.** `device/firefly.py:302` and `registers/firefly4.json:40` deliberately disable serial-number access after rejecting the x12 address. X4 Table 43 actually specifies page-0 bytes 196–211 (`0xC4`, length 16). This is a missing capability, not justification to assume every installed module obeys that document; add only to the matching identified profile.

## C. CERN-B and cross-family map contamination

**F17 High — CERN-B shifted register blocks are unsupported and contradict the cited manual.** `registers/firefly_cernb.json:10–12`, `:25–32`, `:37–38`, `:69` and `CDR_CONTROL_SUMMARY.md:37–41` claim TX base `0x30`, RX base `0x40`, bias/power arrays and SEU/watchdog control registers. CERN Tables 22/37 instead specify separate module addresses with conventional lower maps. Explicit conflicts:

| JSON entry | Wrong address | Manufacturer definition / correction |
|---|---|---|
| TX bias/config array | `0x30`, 12/48 bytes | Starts in reserved bytes, spans reset/disable/polarity; no such array. Remove. |
| TX power array | `0x3C`, 12 bytes | TX bytes 60–96 reserved. Remove. |
| TX polarity | `0x48` | `0x3A–3B`, Table 29. |
| RX config array | `0x40`, 48 bytes | Spans real amplitude/de-emphasis and reserved space; no such block. Remove. |
| RX channel disable | `0x42` | `0x34–35`, Table 43; current address is amplitude control. |
| RX amplitude | `0x44` | `0x3E–43`, Table 45; current address is de-emphasis. |
| RX de-emphasis | `0x4A` | `0x44–49`, Table 46; current address reserved. |
| CERN_CTRL | `0x60`, four bytes | Overlaps RX LOS mask/TX fault mask plus reserved bytes; not a radiation-hardening register. Remove. |
| CERN_STATUS | `0x64`, two bytes | Reserved, not SEU/watchdog status. Remove. |

The claimed radiation/watchdog/SEU/test-mode capabilities (`firefly_cernb.json:61–66`) have no supporting register definitions in this manual. Treat them as unsupported, not verified hardware features. The Python CERN classes appropriately do **not** expose standard CDR writes; do not “repair” them by applying standard-x12 CDR addresses, which this CERN map reserves.

**F18 Medium — generic map cannot safely describe both x4 and x12.** `registers/firefly.json:4` cites the x4 PDF but presents x12 offsets and widths. For x4 it inherits the F13/F14 errors plus wrong identity offsets. For X12 Rev. 4, its RX disable `0x36` is output disable, and RX polarity `0x3C` is reserved; polarity is `0x3A–3B` (Table 42). Split/deprecate the ambiguous map. Its `MAX_TEMP` prose also says `0x46=77°C`; hexadecimal 46 is decimal 70.

**F19 Medium — every FireFly JSON truncates temperature-history bins.** `firefly12.json:54`, `firefly4.json:53`, `firefly_cernb.json:57`, `firefly.json:48` describe 60 bytes / 20 bins from 128. X12 Table 31/54, X4 Table 53 and CERN Tables 36/53 define **22 three-byte bins, bytes 128–193 (66 bytes)**, followed by peak temperature byte 194. Correct range/count; two hottest bins are currently omitted.

**F20 Medium — variant attribution and side effects are incomplete.** `firefly12.json:2–4` conflates standard x12 and CERN while citing an x4 document. `RESET` is labeled WO although manufacturer tables identify RW. Alarm/status reads can clear latched information (X12 status/interrupt prose; X4 p.53); simple `RO` does not communicate this. Record exact part/revision, TX/RX role, reserved fields, and read-clear semantics. This is especially important for diagnostic evidence preservation.

## D. Si5395

| ID / severity | Source | Evidence, consequence and correction |
|---|---|---|
| S01 High | `device/si5395.py:198–201`; `registers/si5395.json:102` | Any nonzero byte is considered ready. SI Table 16.71 p.106 and readiness section require **exactly `0x0F`**. Worse, `.health` reads other registers first; during startup only DEVICE_READY may be polled, with no page writes/other reads. Check exact ready first through a transport that preserves the manufacturer's polling restrictions; otherwise explicitly require an already-ready precondition. Do not claim the current API safely polls startup. |
| S02 High | `registers/si5395.json:176–196`; `device/si5395.py:120–122` | `0x0B24/25` mislabeled NVM control/status and postamble called NVM commit. SI Tables 16.192/193 define reserved R/W bytes used in the frequency-change pre/postamble, not NVM programming. Actual NVM burn uses `0x00E3=0xC7` with its distinct procedure. Remove false NVM semantics and RO marking for 0x0B25. |
| S03 High | `registers/si5395.json:180–196` | Frequency-change recipe omits required preamble wait and changes preamble order. SI frequency-plan-change section prescribes `0x0B24=C0`, `0x0B25=00`, `0x0540=01`, then **300 ms for A/B/C/D/J/K/L/M, 625 ms for P/E**, then configuration/reset/postamble. Replace with version/grade-aware manufacturer sequence, ideally generated CBPro output. |
| S04 High | `registers/si5395.json:125–126` | Format encoding says 0=LVPECL, 1=LVDS, 2=HCSL, 3=LVCMOS. Table 16.74 p.107 says 0/3 reserved, 1=differential normal, 2=differential low-power, 4=LVCMOS. Amplitude is mode-dependent (section 6.3.2/Table 6.4 p.45), not a universal 0–7=200–1600mV scale. Correct mode/field definitions before configuration use. |
| S05 Medium | `registers/si5395.json:62` | OOF reference enum is shifted: JSON 0=XA/XB,1..4=IN0..3; Table 16.37 p.99 specifies 0..3=IN0..3,4=XA/XB. Wrong setting changes the frequency-monitor reference. |
| S06 High | `registers/si5395.json:140` | P0–P3 fractional enables assigned bits 4–7 of `0x0231`. Tables 16.87–90 pp.114–115 put bit 4 in **each** byte `0x0231–234`. Correct per-input address/bit and preserve mode nibble (`0xB` required). |
| S07 High | `registers/si5395.json:21`, `:172–173` | `0x0A00`, sixteen bytes, is labeled GPIO configuration. SI section 16.8/Table 16.172 onward defines N-divider controls at `0x0A02–05`, not a GPIO block. Remove this invented writable array; it could alter clock divider operation. |
| S08 Low | `registers/si5395.json:209` | Twelve outputs do not have twelve independent MultiSynth dividers. SI Table 16.76/77 discussion p.109 specifies five N0–N4 sources feeding twelve output drivers, with per-output R dividers. Correct architectural description. |

Checked live LOL/HOLD/LOS/OOF bit decoding, device-ID little-endian decode, input select at `0x052A`, hitless bit `0x0536[2]`, reset bit values, and the listed output-driver address stride: no contradiction found. `Clock.reset(soft=False)` uses the right HARD_RST bit despite the misleading `POWER_DOWN` register alias. `Clock.is_locked()` is only a LOL check, not proof that all required inputs are healthy. The JSON maps need further mechanical field-by-field validation before being treated as complete; this review does not certify omitted fields or every CBPro-managed value.

## E. LGA80D

Most severe LGA problems are **passive JSON**, not the implemented telemetry methods.

| ID / severity | Source in `registers/lga80d.json` | Actual vs required command (LGA reference) and correction |
|---|---|---|
| L01 High | line 64 `NVM_WRITE` | `0xD0`, byte `0x5A`, is not a store command: `D0` is **ISENSE_CONFIG**, a two-byte current-sense configuration (p.24 and detailed command). Store is **STORE_USER_ALL `0x15`, Send Byte/no data**, p.22. Remove wrong write recipe; changing current-sense settings can affect protection. |
| L02 High | line 68 `RESET` | `0xDF` is **ASCR_CONFIG**, not reset; `0xA5` is not a documented reset payload there (p.24 and ASCR_CONFIG section). Delete/reset unsupported capability instead of risking control-loop configuration. |
| L03 High | lines 21–23 | VOUT_MAX incorrectly `0x25`, margin high/low `0x2A/2B`. Correct commands **`0x24`, `0x25`, `0x26`**, p.22. Current MAX write changes margin-high, not the maximum clamp. |
| L04 High | lines 30–31 | VIN_UV_WARN/FAULT incorrectly `0x57/58`; correct **`0x58/59`**, p.23. `0x57` is VIN_OV_WARN, so the current label could configure the opposite protection boundary. |
| L05 High | lines 62–63 | Switching frequency incorrectly `0xB0`; actual **FREQUENCY_SWITCH `0x33`**, p.22. `0xB0` is variable-length ASCII USER_DATA_00, p.24. `USER_DATA=0xB1`, fixed four bytes, is unsupported here. Correct command/format, not just names. |
| L06 Medium | line 16 | CLEAR_FAULTS is Send Byte / **no data payload**, not size 1 (p.22 and CLEAR_FAULTS command section). Represent command-only transport explicitly. |
| L07 Medium | lines 54–56 | MFR_ID and MFR_SERIAL are **variable-length SMBus block R/W, up to 32 bytes**, not fixed 12-byte RO (pp.64–67). MFR_MODEL is mentioned in the aggregate storage limit but has no standalone supported-command entry in this edition; do not assert its fixed shape. Python correctly refuses sequential PMBus block reads; preserve that guard until true block transport exists. |
| L08 Low | line 61 | “Max IOUT (880A)” contradicts device rating 80 A (pp.1–2). `MFR_IOUT_MAX` support itself is unverified in this edition. Correct typo and capability claim separately. |

**L09 Medium — normal OFF status is called a fault.** `device/lga80d.py:32–42` defines `has_faults = any(raw status values)`. LGA STATUS_WORD table p.54 defines bit 6 OFF as also asserted when intentionally disabled; bit 11 POWER_GOOD# similarly describes state. Therefore a healthy intentionally-off regulator can be classified faulty. Keep raw values but separate fault/warning masks from off/not-power-good state, or rename this property `has_status_bits`. This is a semantic false positive, not incorrect byte decoding.

**L10 Unsupported claims, not proven absent in all silicon revisions.** JSON entries PHASE `0x04`, VOUT_MODE `0x20`, IOUT_COMMAND/MAX `0x39/3B`, IOUT_OC_FAULT_LIMIT `0x46`, READ_IIN/PIN/POUT `0x89/97/96`, and manufacturer-limit commands `0xA0–A4` are not listed in this edition's supported-command summary (pp.22–25). The documented average overcurrent threshold is `IOUT_AVG_OC_FAULT_LIMIT=0xE7`. Do not present generic PMBus command numbers as proven LGA80D support; require a device-specific source before use. JSON's default address `0x5A` and PMBus 1.3 claims also lack evidence here; this module uses pin-strapped addressing, and summary command `0x98` reports revision value `0x22`. These are documentation/capability gaps pending exact firmware/controller revision.

Checked Python READ_VIN/VOUT/IOUT, temperature sensors 1/3, frequency, status byte widths and little-endian Linear11/Linear16 helpers against LGA command sections. The signed Linear11 mantissa and exponent handling is correct; negative unloaded current is not itself a decoding error. No new wrong telemetry address was found in `LGA80DReg`.

## F. Routing, transport, tests and scope limitations

**R01 High risk, board-map evidence required — preset order changes physical endpoint index.** `registry.py:96–125` assigns `0x20+idx` by sparse dictionary order; `_FireflyBase._encode_command` (`firefly.py:35–39`) subtracts `0x20` and sends that number to MCU `FF`. TF first entry `F2_6` consequently sends **FF 0**, and its next `F1_1` sends **FF 1**. The generic routing function (`registry.py:126` onward) instead assigns fixed slots including TX/RX endpoints. Removing or reordering a preset entry silently changes later wire indices. This is a confirmed implementation property; exact mismatch to every physical board cannot be established from device datasheets. The user's fixed device-11 F2_1 RX and this FPGA project's reviewed physical map are consistent with fixed-slot, not sparse-packed numbering. Require explicit immutable transport index per endpoint; keep population/capability separate. Do not use an unverified preset to choose a hardware write target.

**R02 Medium documentation error — UART pseudo-address vs I2C slave address.** FireFly JSON `uart_address_range` text conflates `0x20–0x3F` with hardware I2C/SMBus addresses. Python uses this as a synthetic class/index namespace; X12 Table 9 and CERN Table 17 specify separate TX/RX TWI addresses. Document ProgCom index, class pseudo-address and physical I2C address separately.

Transport review: `Device.write_reg()` preserves caller-provided byte order. `update_bits()` intentionally supports one byte only; it is **not** a twelve-channel-mask operation, but its documented restriction is not a bug. `read_block()` chunks sequential byte addresses, whereas PMBus override refuses inappropriate sequential use. End-to-end page selection, MCU semaphore/mux handling and preservation across multi-command sequences require the deployed MCU implementation; manufacturer PDFs alone cannot validate them. Shared UART transactions and read/modify/write sequences must be serialized by the caller; no hardware concurrency experiment was performed.

Existing `tests/` contains MCU, FPGA and compatibility tests, not dedicated FireFly/Si5395/LGA datasheet-field tests. They cannot establish correctness of the wrong maps above. No library code was imported or hardware-calling examples executed for this review.

The user's `ff_optpow_dev` labels sequential RSSI pairs as channel 0 upward. X12 Table 52 proves that naming reverses datasheet channels, but that MCU CLI implementation is outside this checkout. **Do not label this a cm_interface RSSI decoder bug or a proven board lane-wiring error.** The proposed optical Rx09 ↔ GT X0Y13 match remains a board-mapping hypothesis until independently checked.

## Recommended repair order (not implemented)

1. Quarantine erroneous control recipes and sparse-index presets; pin exact endpoint/module/revision before writes. Never use the JSON as a hardware-write authority in its current state.
2. Split standard TX, standard RX, x4 and CERN maps. Correct F01–F05 and x4 inherited telemetry first; preserve reserved bits and explicitly document 0-based versus 1-based channels.
3. Add memory-backed tests asserting exact address/page/width/wire order for every public operation, including all twelve channels, invalid input, partial masks and restoration. Make placeholders raise rather than succeed silently.
4. Rebuild each JSON from its pinned manufacturer document, distinguishing RO/read-clear/RW/self-clearing/Send Byte/block protocols. Correct hazardous LGA and Si5395 controls before extending APIs.
5. Validate fixes offline first. A separate user-authorized, serialized hardware gate may then compare raw registers, known module identity and controlled single-channel effects. This report does not authorize that gate.

### Source fingerprints

SHA-256 at audit time:

- `device/firefly.py`: `035b8d68b05adafb4bd8f9c2b6157e3bf8f76f3e27c30a64e3bbe4820337b3f4`
- `device/si5395.py`: `1a421d7ac7dffda25e9a3e5dd93f23cee037482ee6aaa91f5ece18aed568133f`
- `device/lga80d.py`: `b88087e0d8b02a328970344692a61f65347d7861eb4f75c2cac7feed88721c81`

No claim is made that the absence of a finding proves full qualification or that manufacturer-reserved addresses necessarily NACK. A bus-level success is not functional validation.
