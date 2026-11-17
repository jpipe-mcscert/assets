#!/usr/bin/env bash
# Regenerates every derived jPipe logo file from the two master SVGs:
#   jpipe-logo.svg   (crest + wordmark)
#   jpipe-picto.svg  (crest only)
# Outputs: greyscale and one-ink SVGs next to the masters, PDFs in pdf/, PNGs in png/.
# Requires rsvg-convert (brew install librsvg) and python3; the one-ink
# step installs picosvg and skia-pathops into jpipe/.venv on first run.
set -euo pipefail
cd "$(dirname "$0")"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (brew install librsvg)" >&2; exit 1; }

# Greyscale SVG: every hex colour becomes its luma-equivalent grey.
to_grey() {
  python3 -I - "$1" "$2" <<'EOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
def grey(m):
    h = m.group(1)
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    y = round(0.299 * r + 0.587 * g + 0.114 * b)
    return f'#{y:02X}{y:02X}{y:02X}'
svg = open(src).read()
open(dst, 'w').write(re.sub(r'#([0-9A-Fa-f]{6})\b', grey, svg))
EOF
}

# Borderless pictogram: drop the white halo paths (edge1, edge2) and the
# 14-unit margin the viewBox reserves for them.
python3 -I - <<'EOF'
import re
svg = open('jpipe-picto.svg').read()
svg, n = re.subn(r'<path id="edge\d" fill="#FFFFFF" stroke="#FFFFFF"[^>]*/>', '', svg)
assert n == 2, f'expected 2 white border paths in jpipe-picto.svg, found {n}'
old = 'viewBox="-14 -14 362 424" height="424" width="362"'
assert old in svg, 'jpipe-picto.svg viewBox changed; update export.sh'
svg = svg.replace(old, 'viewBox="0 0 334 396" height="396" width="334"')
open('jpipe-picto-noborder.svg', 'w').write(svg)
EOF

to_grey jpipe-logo.svg           jpipe-logo-bw.svg
to_grey jpipe-picto.svg          jpipe-picto-bw.svg
to_grey jpipe-picto-noborder.svg jpipe-picto-noborder-bw.svg

# One-ink SVG, for single-colour printing (screen print, embroidery, stamps,
# engraving, vinyl cutting). Ink: the black linework, plus the J medallion
# kept solid so the J still reads (knocked out). Every other fill is paper,
# and paper is transparent, not white, so the mark prints in one ink on any
# stock. The result is a single plain path, with no mask, clip or gradient, so
# PDF exports and print tools keep it as vector. Getting there takes path
# boolean operations, done with picosvg and skia-pathops in a local .venv.
# The ink is black; change INK below for another colour. The pictogram is
# built from the borderless one: its white halo would be paper anyway.
VENV=.venv
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q picosvg==0.23.0 skia-pathops==0.9.2
fi

to_one_ink() {
  "$VENV/bin/python" -I - "$1" "$2" <<'EOF'
import re, sys
import pathops
from picosvg.svg import SVG
from picosvg.svg_pathops import skia_path, svg_commands
from picosvg.svg_types import SVGPath
src, dst = sys.argv[1], sys.argv[2]
INK = '#000000'
svg = open(src).read()
# Highlight strips on the shield's lower facets overlap the black facet lines;
# as paper they would notch those lines, so drop them.
svg, n = re.subn(r'<path\s+id="path1(?:3[02468]|4[024])"[^>]*/>', '', svg)
assert n == 8, f'expected 8 facet highlight paths in {src}, found {n}'
# picosvg resolves transforms, clips and strokes into plain filled shapes,
# in paint order. Replay them: ink shapes add to the ink area, paper shapes
# cut it. Ink is black, or a gradient (only the medallion has one).
pico = SVG.fromstring(svg).topicosvg(allow_text=False)
ink = pathops.Path()
for shape in pico.shapes():
    fill = shape.fill.lower()
    is_ink = fill.startswith('url(') or fill in ('#000000', '#000', 'black')
    op = pathops.PathOp.UNION if is_ink else pathops.PathOp.DIFFERENCE
    ink = pathops.op(ink, skia_path(shape.as_cmd_seq(), shape.fill_rule), op)
d = SVGPath.from_commands(svg_commands(ink)).d
vb = pico.view_box()
open(dst, 'w').write(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    f'viewBox="{vb.x:g} {vb.y:g} {vb.w:g} {vb.h:g}" width="{vb.w:g}" height="{vb.h:g}">'
    f'<path fill="{INK}" d="{d}"/></svg>\n')
EOF
}

to_one_ink jpipe-logo.svg           jpipe-logo-1ink.svg
to_one_ink jpipe-picto-noborder.svg jpipe-picto-1ink.svg

PICTOS="jpipe-picto jpipe-picto-bw jpipe-picto-noborder jpipe-picto-noborder-bw jpipe-picto-1ink"

mkdir -p pdf png
for name in jpipe-logo jpipe-logo-bw jpipe-logo-1ink $PICTOS; do
  rsvg-convert -f pdf "$name.svg" -o "pdf/$name.pdf"
done

# Logo (wide): sizes are widths. Pictogram (tall): sizes are heights.
for w in 256 512 1024 2048; do
  for name in jpipe-logo jpipe-logo-bw jpipe-logo-1ink; do
    rsvg-convert -w "$w" "$name.svg" -o "png/$name-$w.png"
  done
done
for h in 64 128 256 512 1024; do
  for name in $PICTOS; do
    rsvg-convert -h "$h" "$name.svg" -o "png/$name-$h.png"
  done
done

echo "Exported to $(pwd)/{pdf,png} and *-bw.svg, *-1ink.svg"
