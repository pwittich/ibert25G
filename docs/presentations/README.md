# Project talk

[PowerPoint](vu13p_25g_project_talk.pptx) · [PDF](vu13p_25g_project_talk.pdf) ·
[Speaker notes](vu13p_25g_project_talk_speaker_notes.txt)

The 28-slide deck is intended for experimental particle physicists and LHC
detector/readout engineers. It opens with:

1. A title and project scope.
2. Deployment, SSH, and status checks.
3. A three-minute inter-FPGA command with logging and automatic counter discovery.
4. FireFly quad selectors and their current limitations.
5. The actual 2026-10-27 result: 54/54 fitted receivers per endpoint, zero
   errors/native lock losses, and approximately 4.64e12 bits per lane.

The remaining slides include an editable [FPGA firmware block diagram](../fpga-firmware.md)
and explain the design partition, I2C mailbox, embedded
MicroBlaze firmware, CDC/timing choices, verification, statistical meaning,
telemetry and unresolved limitations. The final three slides are technical
backups. Diagrams and tables are editable PowerPoint objects; the scientific
plots also have standalone PNG/SVG copies under `assets/`.

Commands assume the updated runtime is deployed with clean `cm_interface`
v1.0.3. The measured result predates the automatic sequence-discovery change;
that operator-interface update has focused offline coverage. Refreshing this
deck does not represent a new hardware run. See [HOWTO.md](../../HOWTO.md)
for the full procedure and [the hardware record](../all-links-v2-inter-fpga-hardware-gate.md)
for archived evidence.

## Regenerate

The generator reads the archived 180-second raw log under
`build/diagnostic_archive/`. That generated evidence must be available locally;
it is not supplied by a fresh Git clone alone.

```bash
python3 -m pip install python-pptx matplotlib pillow
python3 docs/presentations/make_project_talk.py
inkscape docs/fpga-firmware-block-diagram.svg --export-type=png \
    --export-width=1800 --export-filename=docs/fpga-firmware-block-diagram.png
libreoffice --headless --convert-to pdf --outdir docs/presentations \
    docs/presentations/vu13p_25g_project_talk.pptx
```

The Python generator creates the PPTX, text speaker notes, scientific plot
assets and firmware diagram SVG. Inkscape creates the standalone diagram PNG;
LibreOffice creates the PDF preview.
