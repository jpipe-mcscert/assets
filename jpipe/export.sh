#!/usr/bin/env bash
# Regenerates every derived jPipe logo file from the two master SVGs:
#   jpipe-logo.svg   (crest + wordmark)
#   jpipe-picto.svg  (crest only)
# Outputs: greyscale SVGs next to the masters, PDFs in pdf/, PNGs in png/.
# Requires rsvg-convert (brew install librsvg) and python3.
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

PICTOS="jpipe-picto jpipe-picto-bw jpipe-picto-noborder jpipe-picto-noborder-bw"

mkdir -p pdf png
for name in jpipe-logo jpipe-logo-bw $PICTOS; do
  rsvg-convert -f pdf "$name.svg" -o "pdf/$name.pdf"
done

# Logo (wide): sizes are widths. Pictogram (tall): sizes are heights.
for w in 256 512 1024 2048; do
  for name in jpipe-logo jpipe-logo-bw; do
    rsvg-convert -w "$w" "$name.svg" -o "png/$name-$w.png"
  done
done
for h in 64 128 256 512 1024; do
  for name in $PICTOS; do
    rsvg-convert -h "$h" "$name.svg" -o "png/$name-$h.png"
  done
done

echo "Exported to $(pwd)/{pdf,png} and *-bw.svg"
