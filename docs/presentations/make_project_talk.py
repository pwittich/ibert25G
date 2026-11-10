#!/usr/bin/env python3
"""Generate the editable VU13P project talk and its standalone scientific plots.

Requires python-pptx, matplotlib and Pillow. Run from any directory.
All engineering claims refer to repository evidence; no hardware is accessed.
"""
from pathlib import Path
import ast
import math
import re
from html import escape

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.oxml.xmlchemy import OxmlElement

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent.parent
ASSETS = OUT / 'assets'
ASSETS.mkdir(exist_ok=True)
LOG = ROOT / 'build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.log'
REPORT = LOG.with_suffix('.report.md')
NAVY = '14283F'
TEAL = '007E87'
BLUE = '2565A7'
AMBER = 'C97714'
RED = 'B74D4D'
INK = '23384E'
MUTED = '52677D'
BG = 'F3F6FA'
WHITE = 'FFFFFF'
PALE = 'DDECF0'
FONT = 'Liberation Sans'
MONO = 'DejaVu Sans Mono'

def rgb(s):
    return RGBColor.from_string(s)

prs = Presentation()
prs.slide_width = Inches(13.333333)
prs.slide_height = Inches(7.5)
prs.core_properties.title = 'Making 25G links measurable — Apollo VU13P link-test platform'
prs.core_properties.subject = 'Architecture, I2C interface, MicroBlaze integration, verification and hardware results'
prs.core_properties.author = 'VU13P 25G project'
prs.core_properties.keywords = 'LHC, instrumentation, FPGA, GTY, PRBS31, BER, I2C, MicroBlaze'

def text(s, x, y, w, h, value, size=20, color=INK, bold=False, font=FONT):
    shape = s.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = shape.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = Inches(.015)
    tf.margin_top = tf.margin_bottom = Inches(.01)
    for i, line in enumerate(value.split('\n')):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.font.name, p.font.size = font, Pt(size)
        p.font.bold, p.font.color.rgb = bold, rgb(color)
        p.space_after = Pt(7)
    return shape

def rect(s, x, y, w, h, fill=WHITE, line=None, rounded=False):
    shape = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE,
                               Inches(x), Inches(y), Inches(w), Inches(h))
    shape.fill.solid()
    shape.fill.fore_color.rgb = rgb(fill)
    if line:
        shape.line.color.rgb = rgb(line)
    else:
        shape.line.fill.background()
    if rounded:
        shape.adjustments[0] = .12
    return shape

def arrow(s, x1, y1, x2, y2, color=TEAL, width=2.4):
    c = s.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb, c.line.width = rgb(color), Pt(width)
    tail = OxmlElement('a:tailEnd')
    tail.set('type', 'triangle')
    c.line._get_or_add_ln().append(tail)
    return c

def card(s, x, y, w, h, title, body='', accent=TEAL, fill=WHITE, title_size=23, body_size=19):
    rect(s, x, y, w, h, fill, rounded=True)
    rect(s, x, y + .12, .055, h - .24, accent)
    compact = h < 1.3
    text(s, x + .2, y + (.1 if compact else .16), w - .4,
         .43 if compact else .67, title, title_size, accent, True)
    if body:
        text(s, x + .2, y + (.65 if compact else .94), w - .4,
             h - (.72 if compact else 1.06), body, body_size)

def metric(s, x, y, w, number, label, accent=TEAL):
    rect(s, x, y, w, 1.65, WHITE, rounded=True)
    text(s, x + .2, y + .15, w - .4, .72, number, 39 if len(number) < 10 else 29, accent, True)
    text(s, x + .2, y + .99, w - .4, .52, label, 17, MUTED)

def banner(s, value, y=6.3, color=TEAL):
    rect(s, .5, y, 12.33, .52, color)
    text(s, .7, y + .08, 11.95, .4, value, 18, WHITE, True)

def slide(title, section, source, notes, dark=False):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = rgb(NAVY if dark else BG)
    text(s, .5, .25, 12.3, .3, re.sub(r'^\d+ · ', '', section).upper(), 10, '62C5CC' if dark else TEAL, True)
    text(s, .5, .72, 12.25, 1.0, title, 30, WHITE if dark else NAVY, True)
    rect(s, .5, 1.63, .72, .045, '62C5CC' if dark else TEAL)
    n = len(prs.slides)
    text(s, .5, 7.03, 11.7, .25, source, 9, 'A6BCCF' if dark else MUTED)
    number = text(s, 12.18, 7.0, .6, .3, '%02d' % n, 11, 'A6BCCF' if dark else MUTED)
    number.name = 'slide_number'
    s.notes_slide.notes_text_frame.text = notes + '\n\nEvidence: ' + source
    return s

def table(s, x, y, widths, rows, size=18, row_h=.61):
    obj = s.shapes.add_table(len(rows), len(widths), Inches(x), Inches(y),
                             Inches(sum(widths)), Inches(row_h * len(rows)))
    t = obj.table
    for i, w in enumerate(widths):
        t.columns[i].width = Inches(w)
    for r, row in enumerate(rows):
        t.rows[r].height = Inches(row_h)
        for c, value in enumerate(row):
            cell = t.cell(r, c)
            cell.fill.solid()
            cell.fill.fore_color.rgb = rgb(NAVY if r == 0 else WHITE if r % 2 else 'E8EFF5')
            cell.margin_left, cell.margin_right = Inches(.13), Inches(.09)
            cell.margin_top, cell.margin_bottom = Inches(.09), Inches(.06)
            cell.text = str(value)
            for p in cell.text_frame.paragraphs:
                p.font.name, p.font.size = FONT, Pt(size)
                p.font.color.rgb = rgb(WHITE if r == 0 else INK)
                p.font.bold = r == 0
    return obj


class FirmwareDiagram:
    """Draw native PPT shapes and the equivalent standalone SVG together."""
    def __init__(self, slide):
        self.slide = slide
        self.parts = []

    def box(self, x, y, w, h, fill=WHITE, border=None, rounded=True):
        rect(self.slide, x, y, w, h, fill, border, rounded)
        self.parts.append('<rect x="%g" y="%g" width="%g" height="%g" rx="%g" '
                          'fill="#%s" stroke="%s" stroke-width="1.4"/>' %
                          (x*100, y*100, w*100, h*100, 9 if rounded else 0,
                           fill, '#' + border if border else 'none'))

    def label(self, x, y, w, h, value, size=15, color=INK, bold=False):
        text(self.slide, x, y, w, h, value, size, color, bold)
        pixels = size*100/72
        spans = ''.join('<tspan x="%g" y="%g">%s</tspan>' %
                        (x*100+1.5, y*100+pixels*.9+i*(pixels*1.14+7*100/72), escape(line))
                        for i, line in enumerate(value.split('\n')))
        self.parts.append('<text font-family="Liberation Sans,Arial,sans-serif" '
                          'font-size="%g" font-weight="%s" fill="#%s">%s</text>' %
                          (pixels, '700' if bold else '400', color, spans))

    def route(self, points, color=TEAL, width=2):
        for i, (start, end) in enumerate(zip(points, points[1:])):
            if i == len(points)-2:
                arrow(self.slide, *start, *end, color=color, width=width)
            else:
                c = self.slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT,
                    Inches(start[0]), Inches(start[1]), Inches(end[0]), Inches(end[1]))
                c.line.color.rgb, c.line.width = rgb(color), Pt(width)
        self.parts.append('<polyline points="%s" fill="none" stroke="#%s" '
                          'stroke-width="%g" marker-end="url(#arrow-%s)"/>' %
                          (' '.join('%g,%g' % (x*100,y*100) for x,y in points),
                           color, width*100/72, color))

    def save(self, path):
        defs = ''.join('<marker id="arrow-%s" markerWidth="9" markerHeight="9" '
                       'refX="7" refY="4" orient="auto" markerUnits="userSpaceOnUse">'
                       '<path d="M0,0 L8,4 L0,8 Z" fill="#%s"/></marker>' % (c,c)
                       for c in (TEAL,BLUE,AMBER,MUTED))
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 170 1334 520" '
               'role="img" aria-labelledby="title desc">'
               '<title id="title">All-links v2 FPGA firmware block diagram</title>'
               '<desc id="desc">One VU13P: I2C accesses hardware mailbox/results and clock monitor. '
               'A 200-MHz MicroBlaze with 32-KiB BRAM supervises an AXI test engine. '
               'Four banks of 28 quad controllers manage 112 GTY lanes; lane results cross '
               'receive-clock domains coherently. External MCU and serial pins are outside the boundary.</desc>'
               '<defs>%s</defs><rect x="0" y="170" width="1334" height="520" fill="#%s"/>%s</svg>' %
               (defs, BG, ''.join(self.parts)))
        path.write_text(svg)


def firmware_diagram(s):
    d = FirmwareDiagram(s)
    d.box(2.18, 1.98, 10.65, 4.83, fill='E5EDF5', border='9AB0C5')
    d.label(2.38, 2.04, 9.9, .29, 'ONE VU13P FPGA  ·  same architecture at F1 and F2', 14, BLUE, True)
    # The external MCU/mux is deliberately outside the FPGA boundary.
    d.box(.5, 3.02, 1.42, 1.35, fill=NAVY)
    d.label(.65, 3.15, 1.13, .35, 'Board MCU', 16, WHITE, True)
    d.label(.65, 3.7, 1.15, .58, 'I2C5 + mux\n0x70', 14, WHITE)
    d.box(2.45, 2.83, 1.94, 1.03)
    d.label(2.56, 2.94, 1.71, .31, 'Generic I2C', 16, TEAL, True)
    d.label(2.56, 3.39, 1.71, .31, '7-bit slave 0x2B', 13)
    d.box(2.45, 4.28, 1.94, .97)
    d.label(2.56, 4.37, 1.71, .29, 'Clock monitor', 15, TEAL, True)
    d.label(2.56, 4.78, 1.71, .3, '37 clocks · 0x08–0x9C', 10.5)
    d.box(2.45, 5.62, 1.94, .65)
    d.label(2.56, 5.71, 1.71, .24, 'Clock / reset · MMCM', 12)
    d.label(2.56, 6.02, 1.71, .22, '200 → 100 / 325 MHz', 10.5)
    # Embedded subsystem. Firmware is BRAM initialization within the BIT.
    d.box(4.78, 2.64, 2.28, 3.62, fill='D4E2F1', border='9AB0C5')
    d.box(4.94, 2.83, 1.95, 1.12)
    d.label(5.06, 2.94, 1.71, .32, 'MicroBlaze', 17, BLUE, True)
    d.label(5.06, 3.41, 1.71, .47, '200 MHz\nIRQ + Wakeup', 13)
    d.box(4.94, 4.57, 1.95, .95)
    d.label(5.06, 4.67, 1.71, .29, '32 KiB BRAM', 15, BLUE, True)
    d.label(5.06, 5.08, 1.71, .3, 'ELF embedded in BIT', 11.5)
    d.label(4.97, 5.82, 1.96, .3, 'MDM / JTAG debug', 12, MUTED)
    # One logical engine contains both management logic and RX-domain counters.
    d.box(7.45, 2.83, 2.62, 3.44, fill=WHITE, border='9AB0C5')
    d.label(7.58, 2.96, 2.36, .38, 'HDL test engine', 18, AMBER, True)
    for yy, title, detail in [
            (3.52, 'Mailbox / result window', 'I2C bytes ↔ AXI registers'),
            (4.18, 'Job + TX-session control', 'Duration, RX mask, barriers'),
            (4.84, '112 lane engines', 'Counters in RX clock domains'),
            (5.5, 'Banked result storage', 'Coherent snapshots; run ID')]:
        d.box(7.58, yy, 2.35, .61, fill='EDF3F8')
        d.label(7.67, yy+.045, 2.17, .24, title, 12.5, INK, True)
        d.label(7.67, yy+.345, 2.17, .23, detail, 10.5, MUTED)
    d.box(10.56, 2.83, 2.05, 1.2)
    d.label(10.68, 2.95, 1.8, .29, '28 quad controllers', 14, TEAL, True)
    d.label(10.68, 3.43, 1.8, .51, '4 SLR banks\n6 / 8 / 8 / 6 quads', 12)
    d.box(10.56, 4.85, 2.05, 1.42)
    d.label(10.68, 4.96, 1.8, .31, '112 GTY channels', 15, TEAL, True)
    d.label(10.68, 5.45, 1.8, .7, 'PRBS gen/check + DRP\n56 optical + 56 direct', 11.5)
    # Routes: mailbox bypasses the CPU; the CPU accesses it through AXI.
    d.route([(1.92,3.48),(2.45,3.48)], TEAL)
    d.route([(3.42,2.83),(3.42,2.48),(9.99,2.48),(9.99,3.81),(9.93,3.81)], TEAL)
    d.label(5.0, 2.32, 5.1, .23, 'Direct hardware mailbox / result access', 10.5, TEAL)
    d.route([(3.15,3.86),(3.15,4.28)], TEAL)
    d.route([(3.68,4.28),(3.68,3.86)], TEAL)
    d.route([(6.89,3.49),(7.45,3.49)], BLUE)
    d.label(6.76, 3.13, .85, .29, 'AXI4-Lite', 10.5, BLUE)
    d.route([(7.45,3.91),(6.89,3.91)], AMBER)
    d.label(6.92, 3.67, .5, .22, 'IRQ', 9.5, AMBER)
    d.route([(5.53,3.95),(5.53,4.57)], BLUE)
    d.route([(6.38,4.57),(6.38,3.95)], BLUE)
    d.label(5.76, 4.22, .55, .25, 'LMB', 10.5, BLUE)
    d.route([(10.07,3.26),(10.56,3.26)], TEAL)
    d.route([(10.56,3.7),(10.07,3.7)], TEAL)
    d.route([(11.59,4.03),(11.59,4.85)], TEAL)
    d.label(10.61, 4.15, 1.98, .29, 'Reset / PRBS controls', 11, TEAL)
    d.label(10.61, 4.5, 1.98, .27, '12 × REFCLK0 inputs', 11, MUTED)
    d.route([(10.56,5.18),(10.07,5.18)], BLUE)
    d.route([(12.61,5.3),(13.12,5.3)], TEAL)
    d.route([(13.12,5.9),(12.61,5.9)], TEAL)
    d.label(10.35, 6.39, 2.7, .27, 'Serial I/O: 25.78125 Gb/s', 10.5, TEAL)
    d.label(2.43, 6.43, 7.8, .28,
            'Clock-domain crossings use synchronizers / handshakes; management logic runs at 200 MHz.', 11, MUTED)
    d.save(ROOT / 'docs/fpga-firmware-block-diagram.svg')

# Read the actual run evidence for the charts and result slide.
records = {'F1': [], 'F2': []}
power, temps = {}, {'F1_TEMP': {}, 'F2_TEMP': {}}
for line in LOG.read_text().splitlines():
    m = re.match(r'RECORD site=(F[12]) run=(\d+) lane=(\d+) data=(\{.*\})', line)
    if m:
        records[m[1]].append(ast.literal_eval(m[4]))
    f = dict(re.findall(r'([\w]+)=([^ ]+)', line))
    if line.startswith('POWER12V '):
        power[f['label']] = float(f['watts'])
    if line.startswith('FPGA_DIODE_TEMP '):
        temps[f['sensor']][f['label']] = float(f['celsius'])
for site, values in records.items():
    assert len(values) == 54, site
    assert all(r['errors'] == r['lock_losses'] == 0 for r in values)
N = min(r['tested_bits'] for values in records.values() for r in values)
ber95 = -math.log(.05) / N
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 13,
                     'axes.spines.top': False, 'axes.spines.right': False,
                     'axes.labelcolor': '#23384E', 'text.color': '#23384E',
                     'xtick.color': '#52677D', 'ytick.color': '#52677D',
                     'savefig.facecolor': 'white'})
t = np.logspace(1, math.log10(43200), 250)
fig, ax = plt.subplots(figsize=(8.2, 3.85))
ax.loglog(t / 60, -math.log(.05) / (25.78125e9 * t), color='#007E87', lw=3)
ax.scatter([3], [ber95], color='#C97714', s=90, zorder=3)
ax.annotate('180 s: %.2g per lane' % ber95, xy=(3, ber95), xytext=(5, 3e-12),
            arrowprops={'arrowstyle': '-', 'color': '#C97714'}, color='#97600C', fontsize=12)
ax.axhline(1e-12, color='#A3B4C3', ls='--', lw=1)
ax.set_xlabel('Valid measurement time (minutes)')
ax.set_ylabel('One-sided 95% upper BER bound')
ax.grid(True, which='major', alpha=.2)
fig.tight_layout()
for ext in ('png', 'svg'):
    fig.savefig(ASSETS / ('zero_error_ber95.' + ext), dpi=180)
plt.close(fig)
labels = ['pre', 'during_1_of_2', 'during_2_of_2', 'post']
x = np.arange(4)
fig, axes = plt.subplots(1, 2, figsize=(11.6, 3.8))
axes[0].plot(x, [power[l] for l in labels], '-o', color='#007E87', lw=2.5)
axes[0].set_ylabel('12-V input power (W)')
axes[0].set_ylim(180, 215)
for sensor, color, label in [('F1_TEMP', '#2565A7', 'F1'), ('F2_TEMP', '#C97714', 'F2')]:
    axes[1].plot(x, [temps[sensor][l] for l in labels], '-o', color=color, lw=2.5, label=label)
axes[1].set_ylabel('FPGA diode temperature (°C)')
axes[1].set_ylim(44, 55)
axes[1].legend(frameon=False, ncol=2)
for ax in axes:
    ax.set_xticks(x)
    ax.set_xticklabels(['Before', '~60 s', '~120 s', 'After'])
    ax.grid(axis='y', alpha=.2)
fig.tight_layout()
for ext in ('png', 'svg'):
    fig.savefig(ASSETS / ('test_telemetry.' + ext), dpi=180)
plt.close(fig)

s = slide('Making 25G links measurable', 'LHC instrumentation · project overview',
          'Apollo / Cornell rev3 • all-links v2 • project evidence through 27 October 2026',
          'Audience: experimental particle physicists and detector/readout engineers. Suggested talk duration: 25 minutes, followed by the three backup slides. '
          'The motivation is reproducible physical-link measurement before detector framing and application traffic. '
          'The current candidate is an autonomous managed-GTY PRBS engine, not a vendor IBERT core. '
          'All architecture and performance numbers in this talk are specific to the recorded VU13P build and bench evidence.', dark=True)
text(s, .55, 2.08, 7.1, 1.45, 'A reproducible link-test platform\nfor a dual-VU13P blade', 30, WHITE)
text(s, .55, 4.12, 6.6, 1.3, 'Parallel FPGA measurements\nI2C control · MicroBlaze supervision\nAudited builds · recorded hardware evidence', 22, 'C9DCEB')
text(s, 8.0, 2.08, 4.6, .9, '25.78125', 54, '62C5CC', True)
text(s, 8.1, 3.12, 4.2, .5, 'Gb/s per GTY lane', 24, WHITE)
for j in range(7):
    yy = 4.12 + j * .25
    for i in range(7):
        xx = 8.1 + i * .53
        arrow(s, xx, yy, xx + .42, yy, '62C5CC' if (i + j) % 3 else '55778F', 1.8)
text(s, .55, 6.22, 11.9, .5, 'From interactive bring-up to an auditable measurement', 22, '62C5CC', True)
opening = s

s = slide('How-to: prepare the blade and check status', 'how-to · prepare',
          'HOWTO.md, Quick start and deployment; all_links_v2_timed_status.py',
          'Start the talk with the operator view. Both FPGAs must already contain the audited all-links v2 bitstream; it includes the MicroBlaze program. '
          'Deploy the updated scripts and clean cm_interface v1.0.3 before using the simplified commands. The old temporary bundle used for the original hardware run predates automatic sequence discovery. '
          'The /home/cms/25G-v1.0.3 directory shown here is the persistent installation example in HOWTO.md, not a claim that it has already been installed on a particular blade. '
          'SSH directly to the intended blade. The status script checks both identities and required clocks and reads board telemetry. Require healthy idle/session-off state before testing. '
          'The test process acquires the MCU lock, discovers stable sequence/run state itself and rechecks it before submitting commands. No operator bookkeeping is required. '
          'All optical partners must tolerate PRBS31 because the firmware has one shared TX session enable.')
for i, (a, b) in enumerate([
        ('Check image', 'Both sites: 0x00020501'),
        ('Deploy scripts', 'Clean cm_interface v1.0.3'),
        ('Read status', 'Healthy idle + valid clocks'),
        ('Confirm TX safety', 'All optical partners safe')]):
    card(s, .55 + i * 3.18, 2.0, 2.78, 1.65, a, b, AMBER if i == 3 else TEAL,
         title_size=20, body_size=17)
rect(s, .55, 3.85, 12.22, 1.73, NAVY, rounded=True)
text(s, .8, 4.08, 11.7, 1.26,
     'ssh cms@apollo3010-1\n'
     'cd /home/cms/25G-v1.0.3   # install/refresh as in HOWTO.md\n'
     'python3 -u all_links_v2_timed_status.py', 19, WHITE, font=MONO)
banner(s, 'Sequence/run values are read automatically under the MCU lock; no counters to copy.')
quickstart_setup = s

s = slide('How-to: choose FireFly optical receive quads', 'how-to · selected optical links',
          'HOWTO.md; test_all_links_v2_firefly_loopback.py; current selector limits',
          'This is the alternative optical-path test, not an additional command to run as part of every direct-link procedure. '
          'Select a physically connected set within q121 through q134. A single quad, inclusive ranges and comma-separated combinations are accepted. '
          'The same receive set is measured at both F1 and F2, with four lanes per selected quad. On the recorded bench q121–q124 self-loop independently on each site. '
          'The receive selector does not limit TXs; all112 per FPGA send PRBS31 during the shared session. '
          'The direct runner currently uses its fixed54 fitted receivers at each endpoint and has no arbitrary2xx selector. '
          'The example omits manual sequence/run arguments because the updated runtime discovers them. Preserve stdout/stderr in a unique log as described in HOWTO.md. '
          'After completion run the status script and inspect the result before starting a new measurement.')
rect(s, .55, 2.02, 8.47, 3.75, NAVY, rounded=True)
optical_command = [
    'quads=q121-q124', '',
    'python3 -u test_all_links_v2_firefly_loopback.py "$quads" ' + chr(92),
    '  --duration-seconds 180 ' + chr(92),
    '  --acknowledge-all-managed-tx', '',
    'python3 all_links_v2_timed_status.py'
]
text(s, .76, 2.25, 8.03, 3.25, '\n'.join(optical_command), 15, WHITE, font=MONO)
text(s, 9.4, 2.18, 3.25, .55, 'Receive-set examples', 21, TEAL, True)
text(s, 9.4, 3.0, 3.2, 1.4, 'q121\nq121-q124\nq121,q124,q130', 17, BLUE, font=MONO)
text(s, 9.4, 4.73, 3.1, .82, 'Use only quads with the intended optical partner or loopback.', 18, INK)
banner(s, 'FireFly supports quad sets; the direct CLI uses all fitted RXs. Both activate all TXs.')
quickstart_firefly = s

s = slide('The useful output is evidence, not just a green link', '01 · motivation',
          'README.md; HOWTO.md; docs/all-links-v2-inter-fpga-hardware-gate.md',
          'Relate this to LHC commissioning: many serial links, changing optical connections and startup states, and the need to reproduce a failure without moving the goalposts. '
          'A lock indication is a prerequisite, not a BER measurement. The tested-bit denominator, defined window, acquisition policy and preserved failure evidence make results comparable. '
          'This project demonstrates physical PRBS testing; detector event protocols, FEC behavior, radiation tolerance and production qualification are outside these results.')
card(s, .5, 2.05, 3.95, 3.65, 'Coverage', 'Exercise many lanes together.\n\nKeep physical lane ownership and fitted-channel masks explicit.')
card(s, 4.69, 2.05, 3.95, 3.65, 'Autonomy', 'Let FPGA logic time and count.\n\nMake the result independent of Linux scheduling and I2C bandwidth.', BLUE)
card(s, 8.88, 2.05, 3.95, 3.65, 'Traceability', 'Retain exact image, settings and counters.\n\nArchive failures as well as passes.', AMBER)
text(s, .68, 5.83, 12.0, .36, 'PRBS31: reproducible pseudo-random bits  ·  BER: errors / valid tested bits', 18, MUTED)
banner(s, 'For commissioning: distinguish lock, acquisition, valid exposure and measured errors.')

s = slide('One blade: two FPGAs, two classes of 25G links', '02 · hardware scope',
          'README.md; scripts/all_links_v2_timed_contract.py',
          'Each FPGA owns 112 GTY channels in 28 quads: 56 optical FireFly lanes and 56 nominal direct FPGA-to-FPGA lanes. '
          'The direct test uses 54 fitted receivers per endpoint; F1 global70/71 and F2 global96/97 are omitted. '
          'There are twelve physical managed-GT REFCLK buffers per FPGA, with 322.265625-MHz REFCLK0 sources. '
          'The 10-Gb/s AXI chip-to-chip lanes are deliberately excluded. The 2.8875-Tb/s figure is nominal aggregate TX capacity per FPGA, not an all-channel measured result.')
card(s, .65, 2.05, 3.5, 3.0, 'FPGA F1', 'VU13P · 112 GTY lanes\n28 quads\n56 optical + 56 direct')
card(s, 9.18, 2.05, 3.5, 3.0, 'FPGA F2', 'VU13P · 112 GTY lanes\n28 quads\n56 optical + 56 direct')
arrow(s, 4.25, 2.85, 9.02, 2.85, BLUE, 4)
arrow(s, 9.02, 3.65, 4.25, 3.65, BLUE, 4)
text(s, 4.46, 2.15, 4.55, .5, 'q221–q234 · direct links', 21, BLUE, True)
text(s, 4.65, 4.03, 4.0, .7, '54 fitted RXs at each end\n108 measured directions', 21, INK)
text(s, .85, 5.36, 5.3, .8, 'q121–q134 → FireFly optical I/O', 22, TEAL, True)
text(s, 7.5, 5.36, 5.2, .8, 'FireFly optical I/O ← q121–q134', 22, TEAL, True)
banner(s, '25.78125 Gb/s per lane · 322.265625-MHz REFCLK0 · 10G AXI C2C excluded')

s = slide('Three layers keep control and measurement separate', '03 · architecture',
          'src/gt_test_engine_core.sv; firmware/gt_test_milestone2.c; scripts/all_links_v2_timed_common.py',
          'Explain the partition in familiar detector terms: host run control, an embedded supervisory endpoint, and a deterministic hardware instrument. '
          'MicroBlaze polls for a new mailbox request when idle, validates it and programs the engine. During the acquisition/measurement job it sleeps until the engine interrupt; it does not poll individual lanes. '
          'Bounded polling for TX-session application acknowledgement exists in the session control path. The HDL engine and per-lane logic own timing, acquisition, native counters, CDC and immutable publication.')
card(s, .5, 2.12, 3.7, 3.45, 'Python + cm_interface', 'Choose run, mask and duration\nCheck clocks and telemetry\nSave logs and reports', TEAL)
card(s, 4.8, 2.12, 3.7, 3.45, 'MicroBlaze supervisor', 'Validate the mailbox request\nWrite one AXI descriptor\nSleep; wake on completion', BLUE)
card(s, 9.1, 2.12, 3.7, 3.45, 'Parallel HDL engine', '28 quad controllers\n112 lane engines\nHardware timing and snapshots', AMBER)
arrow(s, 4.25, 3.67, 4.7, 3.67)
arrow(s, 8.55, 3.67, 9.0, 3.67, BLUE)
banner(s, 'I2C moves commands and summaries; the FPGA measures the high-speed streams.')

s = slide('Inside one FPGA: firmware block diagram', 'architecture · one FPGA instance',
          'src/gt_test_direct_quad_v6_core.sv; src/gt_test_engine_core.sv; scripts/create_all_links_v2_project.tcl',
          'This is a logical block diagram of the actual all-links v2 image, repeated at F1 and F2. The board MCU and its I2C5/mux path are outside the FPGA boundary. '
          'The generic 0x2B I2C frontend reads the existing clock monitor below byte address0xA0 and accesses the engine hardware mailbox and published result window above it. '
          'This byte path bypasses MicroBlaze. MicroBlaze is an AXI4-Lite master that validates jobs, writes descriptors and handles engine completion, not a software I2C server. '
          'Its32-KiB BRAM contains the ELF as bitstream initialization data; MDM provides JTAG debug. Engine completion drives both interrupt and wakeup. '
          'The engine includes management-domain control and RX-domain lane measurement logic, so the outline is not a single synchronous clock domain. Explicit CDC handshakes bring coherent lane snapshots to banked management-domain result storage. '
          'The four SLR banks contain28 quad controllers distributed6/8/8/6 and manage112 GTY channels. TX and RX PRBS primitives and the DRP error counters are native GT resources. '
          'Twelve physical REFCLK0 buffers supply the managed-GT topology. Fabric control runs at200MHz and the monitored100/325MHz clocks come from the MMCM. '
          'Arrows are grouped functional interfaces, not a full pin-level netlist or a physical floorplan. Both MCU and MicroBlaze access hardware registers through separate frontends; no high-speed event data traverses I2C or the soft CPU.')
firmware_diagram(s)

s = slide('I2C reuses the blade’s existing slow-control path', '04 · board interface',
          'README.md, Generic I2C clock monitor; cm_interface v1.0.3; HOWTO.md',
          'The operator may SSH to Linux on the blade. Python sends ASCII FP transactions over the MCU UART, /dev/ttyUL4 on this blade. '
          'The MCU selects exactly one FPGA through the 0x70 I2C mux and holds the I2C5 software semaphore for the full transaction. '
          'The generic fabric slave is a 7-bit address 0x2B on either FPGA. FPGA selection is outside the register address space. '
          'Preserve this access discipline: two actors sharing the UART or mux can otherwise corrupt the apparent transaction context. JTAG/XVC is a separate programming/debug route, not the timed measurement transport.')
items = [('Python', 'cm_interface'), ('Blade Linux', 'UART /dev/ttyUL4'), ('Board MCU', 'FP transaction'), ('I2C mux', '0x70 · select F1/F2'), ('FPGA slave', '7-bit address 0x2B')]
for i, (a, b) in enumerate(items):
    x0 = .5 + i * 2.51
    card(s, x0, 2.38, 2.26, 1.9, a, b, TEAL if i % 2 == 0 else BLUE, title_size=20, body_size=17)
    if i < 4:
        arrow(s, x0 + 2.29, 3.25, x0 + 2.48, 3.25)
card(s, .5, 4.78, 6.0, 1.22, 'Transaction ownership', 'MCU holds I2C5 semaphore; exactly one FPGA selected.', BLUE, title_size=21, body_size=16)
card(s, 6.77, 4.78, 6.06, 1.22, 'Wire convention', 'Byte addresses; 32-bit values are little-endian.', TEAL, title_size=21, body_size=16)

s = slide('Stable register addresses preserve existing monitoring', '05 · I2C register map',
          'README.md; docs/gt-test-engine.md, I2C mailbox; src/gt_test_engine_core.sv',
          'The clock-monitor ABI is retained below 0xA0. The MCU convention rNN corresponds to byte address 4*NN. '
          'There are 37 direct-kHz readings in r02–r38 and a format/validity word at r39. 0x434DA501 means valid publication, CM identifier, 37 clocks, format one. '
          'The command mailbox occupies 0xA0–0xFF. A result selector exposes eight words for one lane, avoiding a large I2C address space. '
          'Show only the grouped map here; the exact request offsets are in the backup slide. The same addresses serve either FPGA after mux selection.')
table(s, .55, 1.95, [2.5, 4.4, 5.3], [
    ['Byte addresses', 'Function', 'Reason'],
    ['0x00–0x07', 'Two scratch words', 'Simple connectivity checks'],
    ['0x08–0x98', '37 clock readings, in kHz', 'Keep existing clock readout'],
    ['0x9C', 'Clock status: 0x434DA501', 'Validity and format are explicit'],
    ['0xA0–0xBC', 'Sequence + command + RX mask', 'Separate request from executable job'],
    ['0xC0–0xCC', 'Versions, state, result selector', 'Identify the image and publication'],
    ['0xD0–0xEC', 'Selected 256-bit lane record', 'Stable counters and diagnostics'],
    ['0xF0–0xFC', 'Response, run ID, summary', 'Match completion to the request'],
], size=17, row_h=.55)
banner(s, 'No ×2 scaling: a 322.265625-MHz reference reads approximately 322266 kHz.')

s = slide('The sequence word commits a complete request', '06 · request / response protocol',
          'scripts/all_links_v2_timed_common.py; firmware/gt_test_milestone2.c',
          'The host writes command, duration, timeout and the 112-bit mask first and verifies each field. It writes the new request sequence last. '
          'MicroBlaze accepts a changed sequence, validates the fields, copies them to the executable AXI descriptor and rings one doorbell. '
          'A matching response sequence identifies completion. Run IDs identify receive publications; session start and stop do not consume a receive run. '
          'The result bank is immutable until a new publication. Software compares run ID across multi-transaction collection. The operator scripts now discover predecessor values while holding the MCU lock. Explicit expected-state guards remain optional for automation; rerunning an unguarded command is a new test, not a resume operation.')
steps = [('1', 'Write fields', 'command, time, mask'), ('2', 'Read back', 'verify descriptor'), ('3', 'Write sequence', 'commit last'), ('4', 'Wait / read', 'matching response')]
for i, (n, a, b) in enumerate(steps):
    x0 = .55 + i * 3.18
    text(s, x0 + .12, 2.0, 2.6, .7, n, 38, TEAL, True)
    card(s, x0, 2.88, 2.78, 1.92, a, b, BLUE if i == 2 else TEAL, title_size=21, body_size=18)
    if i < 3:
        arrow(s, x0 + 2.86, 3.85, x0 + 3.09, 3.85)
text(s, .75, 5.2, 11.8, .7, 'Published run ID + immutable result bank → coherent multi-read collection', 23, BLUE, True)
banner(s, 'The script discovers sequence/run state under the MCU lock and checks it before submission.')

s = slide('MicroBlaze is a small embedded supervisor', '07 · processor design',
          'scripts/create_milestone3_project.tcl; firmware/gt_test_milestone2.c and .ld',
          'The generated subsystem has one MicroBlaze v11 core at 200 MHz, 32 KiB of local instruction/data BRAM through the local memory buses, no caches and no operating system. '
          'It has one AXI4-Lite master to the test engine at 0x44A00000. One level-sensitive engine interrupt drives both the Interrupt input and Wakeup[0], so a sleeping core actually resumes. '
          'The fixed 0x10 interrupt vector services that source and clears the pending level. MDM provides JTAG debug and a second wakeup source. '
          'This avoids a full software platform, external DDR, an AXI interrupt controller, and timing-sensitive software polling of the measurement datapath.')
card(s, .55, 2.02, 3.6, 2.05, '32 KiB block RAM', 'Local instruction + data storage\nNo external DDR needed', TEAL)
card(s, 4.86, 2.02, 3.6, 2.05, 'MicroBlaze · 200 MHz', 'Freestanding C + startup assembly\nNo OS or caches', BLUE, title_size=21, body_size=18)
card(s, 9.17, 2.02, 3.6, 2.05, 'HDL test engine', 'AXI4-Lite at 0x44A00000\nHardware owns job timing', AMBER, title_size=22, body_size=18)
arrow(s, 4.22, 3.01, 4.78, 3.01)
arrow(s, 8.53, 3.01, 9.09, 3.01, BLUE)
arrow(s, 10.94, 4.31, 6.63, 4.31, AMBER)
text(s, 6.5, 4.55, 6.1, .6, 'Completion level → Interrupt + Wakeup', 21, AMBER, True)
text(s, .75, 5.45, 11.7, .6, 'Validate → launch one descriptor → sleep during the job → acknowledge completion', 21, INK)

s = slide('The firmware is part of the FPGA image', '08 · build and boot',
          'scripts/build_all_links_v2_firmware.sh; scripts/create_all_links_v2_project.tcl; bit-generation Tcl',
          'The reproducible build compiles startup assembly and C with matching MicroBlaze little-endian flags and a fixed linker script. '
          'The linker places the reset and interrupt vectors, text, data and stack in local BRAM. Tcl adds exactly one matching ELF, scoped to gt_test_milestone3_bd and microblaze_0. '
          'The software becomes BRAM initialization contents in the built design. The audited routed checkpoint produces the compressed bitstream. '
          'Configuration initializes the memories, releases reset and starts the processor. Thus Hardware Manager and XSDB both load the firmware when programming this exact BIT; a separate debugger download is not needed. '
          'The programmer verifies the standalone ELF hash as provenance, but its programming command is just fpga -file. A BIT made without this ELF association would be a different case.')
pipeline = [('Assembly + C', 'mb-gcc + linker'), ('Matching ELF', 'linked firmware image'), ('Tcl association', 'scope to MicroBlaze'), ('BRAM INIT + BIT', 'compressed artifact')]
for i, (a, b) in enumerate(pipeline):
    x0 = .5 + i * 3.18
    card(s, x0, 2.32, 2.78, 2.05, a, b, TEAL if i != 2 else BLUE, title_size=20, body_size=18)
    if i < 3:
        arrow(s, x0 + 2.85, 3.31, x0 + 3.1, 3.31)
text(s, .75, 4.92, 11.9, .9, 'Configuration loads logic AND local-memory contents.\nThe soft core boots automatically after reset release.', 26, BLUE, True)
banner(s, 'The same audited .bit works through Hardware Manager or XSDB; verify its hash.')

s = slide('Acquisition and measurement are separate phases', '09 · controlled measurement',
          'src/gt_test_direct_quad_v6_core.sv; docs/gt-test-engine.md; AGENTS.md, managed-quad behavior',
          'Startup noise must not enter the physics-style exposure denominator. The managed quad sequence stages TX before RX acquisition, retains a fixed 200,000-cycle or one-millisecond observation, and resets native error counters after acquisition/lock. '
          'Only then does the requested timed measurement start. External mode keeps LOOPBACK=000 and avoids resetting an already live RX datapath by default. '
          'At capture, native error counters are read through DRP and RX requalification completes before publication/cleanup. Acquisition diagnostics remain readable through idle. '
          'Near-end PMA loopback uses 010 and a bounded reset sequence; it bypasses the optical path and is a different test.')
stages = [('TX ready', 'power / PLL / clocks'), ('RX acquisition', 'fixed 1-ms observation'), ('Clear counters', 'after lock'), ('Measure', 'hardware-timed window'), ('Capture', 'snapshot + DRP'), ('Publish / stop', 'requalify and cleanup')]
for i, (a, b) in enumerate(stages):
    col, row = i % 3, i // 3
    x0, y0 = .55 + col * 4.22, 2.05 + row * 1.76
    card(s, x0, y0, 3.79, 1.43, a, b, AMBER if i == 3 else TEAL, title_size=21, body_size=17)
banner(s, 'Startup errors are retained as diagnostics, then excluded from the timed measurement.')

s = slide('Count errors and exposure in the receive hardware', '10 · measurement semantics',
          'docs/gt-test-engine.md, lane record; src/all_links_v2_result_copy_bank.sv; timed-test validators',
          'Each lane returns eight 32-bit words: lane/status, 64-bit error field, 64-bit tested bits, native lock losses and 64-bit valid RX cycles. '
          'The error ABI is 64 bits, but the exact native GT PRBS error count is a 32-bit saturating counter zero-extended into that field; do not infer 64-bit native dynamic range. '
          'The native DRP count comes from 0x25E/0x25F. Tested bits equal 80 times valid RX user-clock cycles. The 80-bit parallel interface at 322.265625 MHz corresponds to 25.78125 Gb/s. '
          'Results transfer coherently and the host-visible BRAM bank remains immutable until the next complete publish. Native lock-loss counters do not prove that a link was free of optical disturbances or PRBS errors.')
metric(s, .55, 2.02, 3.9, '80 bits', 'per valid RX user-clock cycle')
metric(s, 4.72, 2.02, 3.9, '322.265625 MHz', 'nominal RX parallel-clock rate', BLUE)
metric(s, 8.89, 2.02, 3.9, '25.78125 Gb/s', 'serial line rate', AMBER)
table(s, .65, 4.15, [3.9, 7.95], [
    ['Observable', 'Meaning'],
    ['Native PRBS errors', 'Exact 32-bit saturating GT counter; 64-bit record field'],
    ['Tested bits', '80 × valid RX cycles; denominator checked against duration'],
    ['Lock / loss / status', 'Separate validity and fault information for each lane'],
], size=18, row_h=.5)
banner(s, 'A locked receiver can still have errors. Zero lock losses is not a zero-error BER result.')

s = slide('Independent receive clocks need explicit handshakes', '11 · crossing clock domains',
          'docs/all-links-v2-timing-strategy.md; src/all_links_v1_slr_bank.sv; v2 routed audit',
          'A VU13P is a large multi-die FPGA. Four SLR banks distribute 28 quads in a 6/8/8/6 pattern. Each quad has its own receive-clock behavior; signals cannot be treated as synchronous to the management clock. '
          'The final v2 design transfers each 256-bit lane snapshot as four stable 64-bit handshakes, registers four result-copy banks and releases reset locally with matched latency. '
          'The participation mask derives from the accepted receive-lane descriptor. Only acquisition-ready and capture-done reductions neutralize unselected quads. All-quad readiness, fault, reset, idle and TX-session barriers remain intact. '
          'V1 incorrectly waited for unselected quads during direct-only acquisition; v2 fixes that functional deadlock without bypassing safety-related barriers.')
for i, q in enumerate([6, 8, 8, 6]):
    x0 = .55 + i * 3.18
    card(s, x0, 2.02, 2.78, 2.54, 'SLR %d' % i, '%d quads\n%d lane engines\nLocal reset release' % (q, q * 4), TEAL if i % 2 == 0 else BLUE, body_size=19)
text(s, .76, 4.63, 11.8, .32, 'SLR = one die region within the FPGA; CDC = clock-domain crossing', 16, MUTED)
text(s, .75, 4.95, 11.9, .8, '256-bit lane snapshot → 4 × 64-bit handshakes → banked publication', 24, BLUE, True)
banner(s, 'Selected RX quads gate acquisition/capture; global health and TX application stay all-quad.')

s = slide('Timing closed after removing central bottlenecks', '12 · physical implementation',
          'docs/all-links-v2-timing-strategy.md; timing-hardened independent audit',
          'Show worst setup slack as an engineering diagnostic, not a benchmark. The original v2 route missed setup by 0.158 ns; reuse of the audited v1 route still missed by 0.119 ns. '
          'The successful change was architectural: registered result banks, narrower CDC transfers and local reset release. '
          'Only true control/reset boundaries are hard-contained; publication-only data placement stays soft. Large hard pblocks and speculative timing exceptions were not the solution. '
          'The final audit has setup +0.046 ns, hold +0.009 ns, no failing endpoints, 220150 fully routed nets, zero routing/Error-DRC failures and all 476 bus-skew groups meeting. These margins qualify the exact archived implementation, not an arbitrary rebuild.')
table(s, .55, 2.02, [5.4, 2.2, 4.6], [
    ['Implementation', 'Setup WNS', 'Result'],
    ['Original v2 normal route', '−0.158 ns', '580 failing endpoints'],
    ['Incremental reuse of v1 route', '−0.119 ns', '93 failing endpoints'],
    ['Banked / split-transfer v2', '+0.046 ns', 'Zero failing endpoints'],
], size=19, row_h=.64)
metric(s, .55, 5.02, 3.9, '+0.009 ns', 'worst hold slack')
metric(s, 4.72, 5.02, 3.9, '476 / 476', 'bus-skew groups pass', BLUE)
metric(s, 8.89, 5.02, 3.9, '0', 'routing / Error-DRC failures', AMBER)

s = slide('Validation is a chain of different kinds of proof', '13 · checks before hardware',
          'README.md; docs/memory/build-state.md; preflight and independent routed audit records',
          'No single test proves the whole system. Functional regressions test direct-only, sparse and all112 selections, changed epochs and session barriers. '
          'Synthesis/preflight proves the intended exact inventory: 112 channels, 28 commons/controllers, twelve managed REFCLK buffers, 112 engines, no IBERT or C2C ownership overlap. '
          'An independent routed audit checks GT properties against the golden reference, physical reset/participation locality, dedicated reference-clock routing, CDC structure and timing exceptions. '
          'The FPGA state-machine encodings are ABI and are protected from recoding. Hashes bind the ELF, checkpoints, BIT and source evidence. Finally the hardware test measures actual links; the earlier checks cannot replace it.')
rows = [
    ['Layer', 'What it establishes'],
    ['RTL / simulation', 'Full/subset masks, changed settings, sessions and atomic results'],
    ['Synthesis / preflight', 'Exact GT ownership, clocks and state-machine structures'],
    ['Independent routed audit', 'GT settings, timing, routing and clock-crossing constraints'],
    ['Artifact provenance', 'Matching ELF / DCP / compressed BIT, each hash-pinned'],
    ['Hardware / telemetry', 'Real measured link behavior and bounded cleanup'],
]
table(s, .55, 2.05, [3.6, 8.6], rows, size=19, row_h=.68)

s = slide('A hardware test is a bounded transaction', '14 · run control',
          'scripts/all_links_v2_timed_common.py; 2026-10-27 180-second evidence log',
          'The procedure verifies image identity, healthy idle/session-off state and stable predecessor sequence/run. Updated scripts discover those counters under the MCU lock; explicit expected-state guards remain optional. It logs all clocks and requires 200/100/325-MHz fabric and all twelve 322-MHz managed references. '
          'Before starting it records board-wide power and temperatures. Session start on both sites uses a 240-second lease for a 180-second measurement. The session application acknowledgement is required before RX measurement. '
          'The host observes both FPGAs simultaneously in RUN and takes telemetry near one-third and two-thirds of the window. It validates complete per-lane publications, then issues normal session stops. '
          'The MCU is serialized, and logs survive pass or failure. The command is never automatically retried: an uncertain link to the host must not replay a hardware action.')
items = [('Preflight', 'identity · clocks · state'), ('Start TXs', '240-s bounded lease'), ('Measure', '180 s · both endpoints'), ('Stop + verify', 'session-off · archive')]
for i, (a, b) in enumerate(items):
    x0 = .55 + i * 3.18
    card(s, x0, 2.25, 2.78, 2.18, a, b, AMBER if i == 2 else TEAL, title_size=21, body_size=18)
    if i < 3:
        arrow(s, x0 + 2.85, 3.28, x0 + 3.1, 3.28)
text(s, .75, 4.97, 11.9, .9, 'Pre / ⅓ / ⅔ / post telemetry: 12-V power, FPGA diodes,\nall LGA80D sensors and populated FireFly temperatures', 23, BLUE, True)
banner(s, 'Measurement duration is timed in the FPGA; Python coordinates and records the run.')

s = slide('Three minutes: 108 fitted receive paths passed', 'early result · 27 October 2026',
          '2026-10-27 report: all-links-v2-timed-inter-fpga-180s-1793111744850372.report.md',
          'This is the new 27 October run after fresh programming of the exact audited image on both sites. The user explicitly approved all outward FireFly TX activity and selected cm_interface v1.0.3, clean commit 64260cf23b01c9da987feda1fbf51567240c2c71. '
          'F1 and F2 each passed all 54 fitted receive lanes with zero PRBS errors and zero native lock losses. Each lane has about 4.640547e12 valid tested bits. '
          'Both sessions stopped at sequence/ack3, receive run1, summary 0x00363601 and healthy idle/session-off state 0x00100000. '
          'This measures all fitted direct links in both directions, not all FireFly receivers. Keep it distinct from prior failures and the statistical limits on a short run. '
          'The automatic sequence-discovery change was added afterward and verified offline; the actual measured result used the archived explicitly guarded launcher. No new hardware test was run merely to refresh this presentation.')
metric(s, .55, 2.05, 5.95, '54 / 54', 'F1 fitted receivers passed')
metric(s, 6.84, 2.05, 5.95, '54 / 54', 'F2 fitted receivers passed', BLUE)
table(s, .65, 4.06, [4.0, 3.95, 3.95], [
    ['Per-endpoint result', 'F1', 'F2'],
    ['PRBS errors / native losses', '0 / 0', '0 / 0'],
    ['Tested bits per lane', '≈ 4.64055 × 10¹²', '≈ 4.64055 × 10¹²'],
    ['Final state', 'Healthy IDLE · TX off', 'Healthy IDLE · TX off'],
], size=19, row_h=.51)
banner(s, 'cm_interface v1.0.3 exercised command writes, lane results, telemetry and clean session stop.')
early_results = s

s = slide('Zero observed errors still gives a finite BER bound', '16 · statistical interpretation',
          'Derived from actual tested-bit counts in the 180-second log; one-sided Poisson zero-count limit',
          'For a stationary independent rare-error model, the probability of zero errors is exp(−BER*N). Setting this to 0.05 gives a one-sided 95%% upper bound −ln(0.05)/N. '
          'Use the observed valid-bit denominator rather than simply multiplying nominal rate by wall-clock runtime. Taking the smallest observed lane denominator, N=%d, gives %.5g. '
          'This bound is per lane. Pooling all 108 paths would require an additional common-rate model and is deliberately not done here. Burst errors, startup dependence, pattern dependence and changing conditions require separate studies.' % (N, ber95))
s.shapes.add_picture(str(ASSETS / 'zero_error_ber95.png'), Inches(.52), Inches(2.0), width=Inches(8.0))
text(s, 9.0, 2.22, 3.7, .6, 'BER₉₅ < −ln(0.05) / N', 23, TEAL, True)
text(s, 9.0, 3.16, 3.6, 1.15, '≈ 6.46 × 10⁻¹³\nper tested lane', 29, BLUE, True)
text(s, 9.0, 4.8, 3.6, 1.0, 'Assumes stationary, independent rare errors.\nNo pooling across lanes.', 18, MUTED)
banner(s, 'Longer exposure tightens the bound; it does not replace tests of startup and changing conditions.')

s = slide('Telemetry provides context for the link result', '17 · same-run operating conditions',
          'Actual pre / one-third / two-thirds / post samples from the 180-second log',
          'These are actual data from the same test, not illustrative curves. The input ADC reports roughly 190 W at idle and 207–208 W while the shared PRBS sessions run. '
          'The immediate post-stop ADC sample can still reflect earlier current; a later independent settled status read measured 189.226 W, F1 50.406 C and F2 46.844 C. '
          'All 28 LGA80D temperature readings and all six physical FireFly temperatures were read at each snapshot. Across the four recorded snapshots, max LGA80D was 51.375 C and max FireFly 45 C. '
          'There are no approved numerical power/temperature trip thresholds in this procedure. Finite readings are evidence completeness, not thermal qualification.')
s.shapes.add_picture(str(ASSETS / 'test_telemetry.png'), Inches(.56), Inches(2.0), width=Inches(12.15))
text(s, .85, 6.13, 11.7, .64, 'Max sampled: FPGA F1/F2 52.66 / 48.03°C · LGA80D 51.38°C · FireFly 45°C', 21, BLUE, True)

s = slide('Preserved failures are part of the design evidence', '18 · lessons from bring-up',
          'docs/all-links-v1-source-milestone.md; timing strategy; inter-FPGA gate; FireFly run-5 report',
          'Avoid telling an uninterrupted success story. V1 had a deterministic direct-only subset deadlock, fixed by registering quad participation and neutralizing only acquisition/capture reductions. '
          'Broad setup failures required changing the source architecture, not accepting a clean route as timing signoff. '
          'An earlier 180-second direct gate failed F2 global98 with a saturated counter and zero native lock losses. A separately authorized power cycle and fresh test passed; that supports but does not prove a transient startup explanation. '
          'The latest FireFly optical-loopback history still has repeatable low errors on F1 lanes1/3/4/6 with lock maintained; q123/q124 and all selected F2 lanes passed the last 90-second optical run. This is an unresolved optical/link-quality problem, not cured by the latest direct-link pass.')
table(s, .55, 2.03, [3.25, 4.25, 4.7], [
    ['Observation', 'Design / procedure response', 'Evidence limit'],
    ['Subset request deadlocked', 'Accepted quad-participation mask', 'Global health barriers retained'],
    ['Wide publication paths failed setup', 'Banked copy + narrower CDC', 'Exact routed build audited'],
    ['F2 direct lane98 failed once', 'Preserved failure; separate fresh gate', 'Root cause remains unproven'],
    ['F1 optical lanes1/3/4/6 errored', 'Keep optical failures visible', 'Lock alone did not predict BER'],
], size=17, row_h=.79)
banner(s, 'A later pass does not erase an earlier failure or establish its cause.')

s = slide('Present scope: selective RX, shared all-lane TX', '19 · operational limits',
          'HOWTO.md; scripts/all_links_v2_timed_contract.py; firmware TX-session validation',
          'The receive mask and TX-session mask are intentionally distinct in the current interface. Firmware accepts TX sessions only with all112 managed transmitters selected, on each FPGA. '
          'Therefore even a q221–q234 direct-only measurement emits PRBS31 out of all FireFly transmitters. Operators must confirm the connected optical equipment can safely receive it. '
          'The FireFly CLI accepts arbitrary quad sets within q121–q134 symmetrically on both sites; the direct CLI currently measures its fixed fitted masks. Arbitrary direct subsets, mixed groups and different optical sets per endpoint need a reviewed CLI extension. '
          'Session-off restores the normal no-PRBS session state; it is not a physical FireFly-disable operation. Native lock-loss counters cannot exclude all optical disturbance modes.')
card(s, .55, 2.08, 5.95, 3.43, 'TX session: all 112 per FPGA', '56 optical + 56 direct TXs\n\nThe current firmware has one shared enable.\nConfirm all optical partners tolerate PRBS31.', AMBER, body_size=20)
card(s, 6.84, 2.08, 5.95, 3.43, 'RX measurement: selected mask', 'FireFly: chosen q121–q134 set\nDirect: 54 fitted RXs per site\n\nOnly selected results determine this test.', TEAL, body_size=20)
banner(s, 'Next interface improvement: independent TX link-class selection with the same application barriers.')

s = slide('How-to: run a three-minute direct-link test', 'how-to · direct inter-FPGA links',
          'HOWTO.md; scripts/test_all_links_v2_inter_fpga.py; all_links_v2_timed_status.py',
          'Use this as orientation, not a request to execute another run. The detailed guide is HOWTO.md. SSH directly to the blade from lnx4189; no extra same-host jump is necessary. '
          'The maintained script source lives in this repository, while the tested v1.0.3 bundle is copied to the blade. The ordinary workstation wrappers still pin v1.0.0; the explicitly authorized October v1.0.3 run used a separately archived wrapper with exact tag/commit checks. '
          'The updated scripts automatically read stable sequence/run state under the MCU lock, log it, and recheck readiness before TX start. All four predecessor flags remain optional guards for automation. A repeated unguarded command is a new test; inspect state after uncertain completion rather than automatically rerunning it. '
          'The direct script writes complete lane records and snapshots; workstation wrappers also write an immutable Markdown report. Direct-on-blade invocations need their own captured log. Run status after the test exits to verify cleanup.')
rect(s, .55, 2.0, 8.45, 3.72, NAVY, rounded=True)
command_lines = [
    'log="inter-fpga-$(date -u +%Y%m%dT%H%M%SZ).log"',
    'set -o pipefail',
    'python3 -u test_all_links_v2_inter_fpga.py ' + chr(92),
    '  --duration-seconds 180 ' + chr(92),
    '  --acknowledge-all-firefly-tx ' + chr(92),
    '  2>&1 | tee "$log"', '',
    'python3 all_links_v2_timed_status.py'
]
text(s, .77, 2.22, 8.0, 3.24, '\n'.join(command_lines), 16, WHITE, font=MONO)
text(s, 9.42, 2.22, 3.1, 2.8, '1  Read current state\n\n2  Confirm TX safety\n\n3  Run once; retain log\n\n4  Verify sessions off', 20, BLUE, True)
banner(s, 'HOWTO.md documents deployment, version checks, quad selectors, logs and recovery rules.')
quickstart_direct = s

s = slide('The result is a reproducible physical-link instrument', '21 · take-home points',
          'Project evidence and HOWTO.md • 27 October 2026',
          'Close with three claims supported by the evidence. First, the parallel hardware engine gives explicit acquisition and valid-exposure semantics independent of host scheduling. '
          'Second, an I2C mailbox and a small embedded supervisor provide integration without a full CPU platform, while allowing both Hardware Manager and XSDB to load the same firmware-bearing BIT. '
          'Third, the exact audited image has measured all54 fitted direct receivers at both endpoints cleanly for180 seconds, with per-lane95% zero-error limits around6.46e-13 under the stated model. '
          'The next engineering work is independent TX-class control, a general direct/mixed selector, and targeted optical-path investigation followed by longer BER runs under chosen conditions. These are proposed improvements, not already demonstrated capabilities.', dark=True)
for i, (title, body) in enumerate([
    ('Hardware owns the exposure', 'Parallel counters, explicit acquisition and coherent snapshots.'),
    ('Slow control remains simple', 'I2C mailbox + a BRAM-resident MicroBlaze supervisor.'),
    ('Evidence remains inspectable', 'Audited image, per-lane denominators, telemetry and preserved failures.')]):
    yy = 2.05 + i * 1.35
    text(s, .7, yy, 1.0, .7, str(i + 1), 38, '62C5CC', True)
    text(s, 1.75, yy, 10.8, .5, title, 26, WHITE, True)
    text(s, 1.75, yy + .55, 10.8, .55, body, 21, 'C9DCEB')
text(s, .75, 6.38, 11.9, .45, 'Next: TX-class control · broader selectors · optical diagnosis · longer exposure', 20, '62C5CC')

s = slide('Backup: the mailbox is small but explicit', 'appendix A · full command/result fields',
          'docs/gt-test-engine.md; firmware/gt_test_engine_regs.h; scripts/all_links_v2_timed_common.py',
          'All locations shown are byte addresses in the generic I2C slave. Each word is little-endian. '
          'The receive command used in the timed direct and optical procedures is0x00010501: parallel BER opcode, PRBS31, external LOOPBACK=000 and millisecond timebase. '
          'Session start is command2, session stop3; they require all112 mask bits and do not advance receive run ID. '
          'Selector0xFE exposes live and retained first-fault platform diagnostics at0xD0–0xEC. The normal lane and clock ABI addresses are unchanged. '
          'The wide command and response interface is owned by hardware and firmware jointly; direct low-level writes should follow the operator scripts rather than an ad hoc byte sequence.')
table(s, .55, 1.93, [2.0, 5.8, 4.4], [
    ['Offset', 'Field', 'Ownership / convention'],
    ['0xA0', 'Request sequence (write last)', 'Host → MCU → FPGA'],
    ['0xA4 / A8 / AC', 'Command / duration / timeout', 'Validate before launch'],
    ['0xB0–0xBC', '112-bit RX mask in four words', 'Low word first'],
    ['0xC0 / C4 / C8', 'FW version / HW version / state', 'Identity and live engine state'],
    ['0xCC', 'Lane selector; 0xFE diagnostics', 'Select result window'],
    ['0xD0–0xEC', 'Eight-word lane result', 'Published immutable bank'],
    ['0xF0 / F4', 'Response sequence / code', 'Match the submitted request'],
    ['0xF8 / FC', 'Published run ID / summary', 'Summary: failed/passed/selected/reason'],
], size=16, row_h=.52)

s = slide('Backup: clock validity and DONE are different checks', 'appendix B · bring-up diagnostics',
          'README.md; cm_interface v1.0.3 MCU runtime page; October programming logs',
          'The 37 clock-monitor values are direct-kHz counts relative to the board200-MHz oscillator; entry0 reports the configured nominal reference. They are not an external precision frequency standard. '
          'The required managedGT references are registers r11,r12,r14–r23; not every visible REFCLK1 monitor is a required clock for this image. '
          'The MCU runtime page0x06 offset0x15 gives raw active-low DONE pins: bit0F1, bit1F2. A low bit means configured. The library enum exposes raw levels and must not be interpreted as active-high configuration status. '
          'DONE does not identify which image is running. Read firmware and hardware versions as well. '
          'The F2 XSDB load emitted PROGRAM_F2_COMPLETE and showed MicroBlaze running, then crashed during shutdown with Tcl_FindHashEntry on deleted table. Independent MCU/I2C checks and the completed subsequent PRBS test establish loaded behavior; no programming retry was made.')
card(s, .55, 2.0, 5.95, 3.9, 'Clock monitor', '37 values · direct kHz\nStatus: 0x434DA501\nRequired fabric: 200 / 100 / 325 MHz\n12 managed-GTY REFCLK0 inputs\nNominal REFCLK: 322.265625 MHz', TEAL, body_size=20)
table(s, 6.84, 2.0, [2.0, 3.95], [
    ['Raw DONE', 'Interpretation (active low)'],
    ['0x00', 'F1 and F2 configured'],
    ['0x02', 'F1 configured; F2 not'],
    ['0x01', 'F2 configured; F1 not'],
    ['0x03', 'Neither configured'],
], size=18, row_h=.65)
banner(s, 'Active-low DONE checks configuration; version, clocks and state identify a live endpoint.')

s = slide('Backup: sources and exact release provenance', 'appendix C · evidence index',
          'All sources are in this repository; full references are also in the speaker notes.',
          'Primary operator documentation: HOWTO.md and docs/all-links-v2-timed-tests.md. Architecture and ABI: docs/gt-test-engine.md, noting its historical milestone sections; the current v2 source and timing record supersede its old topology and snapshot-width descriptions. '
          'Build integration: scripts/create_all_links_v2_project.tcl, scripts/create_milestone3_project.tcl, scripts/build_all_links_v2_firmware.sh, firmware/gt_test_milestone2.c, firmware/gt_test_milestone2_start.S, firmware/gt_test_milestone2.ld. '
          'Physical signoff: docs/all-links-v2-timing-strategy.md and build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/. '
          'Latest measurement: build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.log, its report.md sibling and archived launcher.py. Log SHA25624257c790b0562c47c78a951e88912cd07887602c68423600068a244376ccabf. '
          'Final status: all-links-v2-timed-status-1793113074559486.log. '
          'BIT SHA256163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f; routed DCP323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a; ELF d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c. '
          'Repository HEAD f75213d plus the recorded October working documentation; this talk does not imply a new RTL release.')
card(s, .55, 2.0, 5.95, 2.48, 'Architecture / operation', 'HOWTO.md\ndocs/gt-test-engine.md\ndocs/all-links-v2-timed-tests.md\ndocs/all-links-v2-timing-strategy.md', TEAL, body_size=17)
card(s, 6.84, 2.0, 5.95, 2.48, 'Hardware / provenance', 'docs/all-links-v2-inter-fpga-hardware-gate.md\nFrozen timing-hardened artifact archive\n180-second raw log + immutable report\nExact source and library revision in notes', BLUE, title_size=22, body_size=16)
text(s, .75, 4.9, 11.9, .6, 'Current image: 0x00020501  ·  cm_interface: v1.0.3', 23, BLUE, True)
text(s, .75, 5.65, 11.8, .8, 'Compressed BIT SHA-256\n163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f', 14, INK, font=MONO)

target = OUT / 'vu13p_25g_project_talk.pptx'
# Put practical operation and measured results immediately after the title.
front = [opening, quickstart_setup, quickstart_direct, quickstart_firefly, early_results]
ids = list(prs.slides._sldIdLst)
by_id = {node.id: node for node in ids}
front_ids = [item.slide_id for item in front]
ordered = [by_id[value] for value in front_ids] + [node for node in ids if node.id not in front_ids]
for node in ids:
    prs.slides._sldIdLst.remove(node)
for node in ordered:
    prs.slides._sldIdLst.append(node)
for number, item in enumerate(prs.slides, 1):
    for shape in item.shapes:
        if shape.name == 'slide_number':
            shape.text_frame.paragraphs[0].runs[0].text = '%02d' % number
prs.save(target)
assert len(prs.slides) == 28
notes = []
for i, s in enumerate(prs.slides, 1):
    notes.append('SLIDE %02d\n%s\n' % (i, s.notes_slide.notes_text_frame.text))
(OUT / 'vu13p_25g_project_talk_speaker_notes.txt').write_text('\n'.join(notes))
print('Wrote %s (%d slides)' % (target, len(prs.slides)))
print('Observed minimum bits per lane: %d; one-sided BER95: %.6g' % (N, ber95))
