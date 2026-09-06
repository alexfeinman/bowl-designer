#!/usr/bin/env python3
"""Generate the Segmented Bowl Designer app icon as SVG variants.

A top-down view of a segmented turned bowl: an amber rim, concentric courses of
brick-bonded wood wedges (maple / walnut with a padauk accent course), lightening
toward the centre to read as a concave bowl, on a warm espresso ground.
"""
import math

# ---- palette -----------------------------------------------------------------
BG_C = "#4a3421"; BG_M = "#2c1f15"; BG_E = "#160e08"   # radial ground
RIM_HI = "#ecb75f"; RIM_LO = "#c07f2c"                  # amber bowl edge
MAPLE = (0xE8, 0xD5, 0xA8)
WALNUT = (0x6A, 0x49, 0x31)
PADAUK = (0xB5, 0x53, 0x2A)
GLUE = "#140c07"


def lighten(rgb, t):
    return tuple(round(c + (255 - c) * t) for c in rgb)

def hexc(rgb):
    return "#%02x%02x%02x" % rgb


def sector(cx, cy, r0, r1, a0, a1):
    """Annular-sector path from radius r0..r1 over angle a0..a1 (radians)."""
    x0o, y0o = cx + r1 * math.cos(a0), cy + r1 * math.sin(a0)
    x1o, y1o = cx + r1 * math.cos(a1), cy + r1 * math.sin(a1)
    x1i, y1i = cx + r0 * math.cos(a1), cy + r0 * math.sin(a1)
    x0i, y0i = cx + r0 * math.cos(a0), cy + r0 * math.sin(a0)
    large = 1 if (a1 - a0) > math.pi else 0
    return (f"M{x0o:.2f} {y0o:.2f} A{r1:.2f} {r1:.2f} 0 {large} 1 {x1o:.2f} {y1o:.2f} "
            f"L{x1i:.2f} {y1i:.2f} A{r0:.2f} {r0:.2f} 0 {large} 0 {x0i:.2f} {y0i:.2f} Z")


def bowl_art(cx, cy, R):
    """The segmented-bowl motif centred at (cx,cy) with outer radius R."""
    out = []
    # Rim (bowl edge) — amber annulus.
    rim_in = R * 0.80
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="url(#rim)"/>')
    # Faint glue ring under the rim inner edge.
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{rim_in}" fill="{GLUE}"/>')

    # Concentric courses, outer→inner. (r_outer, r_inner, colA, colB, seg, offset)
    courses = [
        (0.795, 0.630, MAPLE, WALNUT),
        (0.618, 0.470, WALNUT, PADAUK),
        (0.458, 0.320, MAPLE, WALNUT),
        (0.308, 0.170, WALNUT, MAPLE),
    ]
    seg = 16
    step = 2 * math.pi / seg
    gap = 0.045          # angular glue gap (radians)
    for i, (ro, ri, ca, cb) in enumerate(courses):
        ro *= R; ri *= R
        offset = (i * step / 2) - math.pi / 2   # brick-bond stagger; start at top
        # Concavity: lighten toward the centre.
        t = 0.04 + 0.16 * i
        for k in range(seg):
            a0 = k * step + offset + gap / 2
            a1 = (k + 1) * step + offset - gap / 2
            base = ca if k % 2 == 0 else cb
            col = hexc(lighten(base, t))
            out.append(f'<path d="{sector(cx, cy, ri, ro, a0, a1)}" fill="{col}"/>')

    # Centre: a small segmented disk (the glued base) — 8 pie wedges.
    hub = R * 0.170
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{hub*1.03:.2f}" fill="{GLUE}"/>')
    n = 8; st = 2 * math.pi / n
    for k in range(n):
        a0 = k * st - math.pi / 2 + 0.02
        a1 = (k + 1) * st - math.pi / 2 - 0.02
        base = MAPLE if k % 2 == 0 else WALNUT
        col = hexc(lighten(base, 0.34))
        out.append(f'<path d="{sector(cx, cy, 0.0, hub, a0, a1)}" fill="{col}"/>')

    # Concavity shade + top-left specular, clipped to the bowl.
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="url(#concave)"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="url(#spec)"/>')
    # Thin dark outline to seat the bowl on the ground.
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{R-1}" fill="none" '
               f'stroke="#0d0805" stroke-width="{R*0.012:.2f}" opacity="0.55"/>')
    return "\n".join(out)


DEFS = f'''<defs>
  <radialGradient id="ground" cx="38%" cy="32%" r="80%">
    <stop offset="0%" stop-color="{BG_C}"/>
    <stop offset="52%" stop-color="{BG_M}"/>
    <stop offset="100%" stop-color="{BG_E}"/>
  </radialGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="{RIM_HI}"/>
    <stop offset="100%" stop-color="{RIM_LO}"/>
  </linearGradient>
  <radialGradient id="concave" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#000000" stop-opacity="0"/>
    <stop offset="62%" stop-color="#000000" stop-opacity="0"/>
    <stop offset="88%" stop-color="#000000" stop-opacity="0.30"/>
    <stop offset="100%" stop-color="#000000" stop-opacity="0.52"/>
  </radialGradient>
  <radialGradient id="spec" cx="34%" cy="28%" r="46%">
    <stop offset="0%" stop-color="#ffffff" stop-opacity="0.26"/>
    <stop offset="55%" stop-color="#ffffff" stop-opacity="0.05"/>
    <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="14" stdDeviation="22" flood-color="#000000" flood-opacity="0.45"/>
  </filter>
</defs>'''


def svg(body, size=1024):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 1024 1024">\n{DEFS}\n{body}\n</svg>\n')


def variant(kind):
    S = 1024
    if kind == "macos":
        # Padded squircle with a soft drop shadow (modern macOS style).
        m = 100; side = S - 2 * m; rad = 185
        bg = (f'<g filter="url(#shadow)">'
              f'<rect x="{m}" y="{m}" width="{side}" height="{side}" rx="{rad}" ry="{rad}" '
              f'fill="url(#ground)"/></g>')
        art = bowl_art(S / 2, S / 2 + 6, side * 0.398)
        return svg(bg + "\n" + art)
    if kind == "web":
        rad = 150
        bg = f'<rect width="{S}" height="{S}" rx="{rad}" ry="{rad}" fill="url(#ground)"/>'
        art = bowl_art(S / 2, S / 2, S * 0.404)
        return svg(bg + "\n" + art)
    if kind == "maskable":
        # Full-bleed ground; art within the centre 80% safe zone.
        bg = f'<rect width="{S}" height="{S}" fill="url(#ground)"/>'
        art = bowl_art(S / 2, S / 2, S * 0.36)
        return svg(bg + "\n" + art)
    raise ValueError(kind)


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for k in ("macos", "web", "maskable"):
        open(f"{out}/icon_{k}.svg", "w").write(variant(k))
        print(f"wrote {out}/icon_{k}.svg")
