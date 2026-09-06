#!/usr/bin/env python3
"""App icon: flat, bold-outlined 3/4 checkered segmented bowl (line-icon style)."""
import math

INK = "#2b2115"      # outline
MAPLE = "#ecd9ac"
OAK = "#c6883a"
WALNUT = "#6f4a2f"
CREAM = "#f4ecdb"    # interior / tile
TILE = "#f6eeddff"

def P(cx, cy, R, H, phi, tilt):
    return (cx + R*math.cos(phi), cy + H + R*math.sin(phi)*tilt)

def path_pts(pts, close=True):
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    return d + (" Z" if close else "")

def bowl(cx, cy, Rx, tilt=0.34, framing="tile"):
    """Flat checker clipped to the bowl outline, with a cream opening + bold ink."""
    depth = Rx*1.16
    tmax = math.radians(74)
    def R(t): return Rx*math.cos(t)
    def H(t): return depth*math.sin(t)
    o = []
    Rb, Hb = R(tmax), H(tmax)
    Lx, Ly = cx-Rx, cy
    Rxr, Ryr = cx+Rx, cy
    blx, bly = cx-Rb, cy+Hb
    brx, bry = cx+Rb, cy+Hb
    yBot = cy + Hb + Rb*tilt
    sil = (f"M{Lx:.1f} {Ly:.1f} "
           f"C{cx-Rx*1.03:.1f} {cy+depth*0.52:.1f} {cx-Rb*1.18:.1f} {cy+Hb*0.86:.1f} {blx:.1f} {bly:.1f} "
           f"A{Rb:.1f} {Rb*tilt:.1f} 0 0 0 {brx:.1f} {bry:.1f} "
           f"C{cx+Rb*1.18:.1f} {cy+Hb*0.86:.1f} {cx+Rx*1.03:.1f} {cy+depth*0.52:.1f} {Rxr:.1f} {Ryr:.1f} "
           f"A{Rx:.1f} {Rx*tilt:.1f} 0 0 1 {Lx:.1f} {Ly:.1f} Z")

    o.append(f'<clipPath id="body"><path d="{sil}"/></clipPath>')
    o.append(f'<path d="{sil}" fill="{CREAM}"/>')

    # Rectangular checkerboard clipped to the bowl (flat, like the reference).
    NC = 7                                  # columns across the width
    yTop = cy - Rx*tilt                     # from the top of the rim ellipse
    NR = 5                                  # rows down the body
    cw = (2*Rx)/NC
    rh = (yBot - yTop)/NR
    cw_stroke = Rx*0.022
    o.append('<g clip-path="url(#body)">')
    for r in range(NR):
        for c in range(NC):
            x = cx - Rx + c*cw
            y = yTop + r*rh
            # Cream / dark checker; dark cells alternate oak-orange and walnut.
            if (r + c) % 2 == 0:
                col = MAPLE
            else:
                col = OAK if ((r + c) // 2 + r) % 2 == 0 else WALNUT
            o.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cw+1:.1f}" height="{rh+1:.1f}" '
                     f'fill="{col}" stroke="{INK}" stroke-width="{cw_stroke:.1f}"/>')
    o.append('</g>')

    # Interior opening (cream) carves the top → an empty bowl, drawn over the checker.
    o.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{Rx*0.9:.1f}" ry="{Rx*0.9*tilt:.1f}" '
             f'fill="{CREAM}"/>')
    # Far inner wall shadow at the back of the opening.
    ri = Rx*0.9  # noqa
    il = P(cx, cy, ri, 0, math.pi, tilt); ir = P(cx, cy, ri, 0, 0, tilt)
    o.append(f'<path d="M{il[0]:.1f} {il[1]:.1f} A{ri:.1f} {ri*tilt:.1f} 0 0 0 '
             f'{ir[0]:.1f} {ir[1]:.1f}" fill="none" stroke="#dcc7a1" '
             f'stroke-width="{Rx*0.11:.1f}" opacity="0.7"/>')

    # Bold outlines: opening rim + full silhouette.
    sw = Rx*0.055
    o.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{Rx:.1f}" ry="{Rx*tilt:.1f}" '
             f'fill="none" stroke="{INK}" stroke-width="{sw:.1f}"/>')
    o.append(f'<path d="{sil}" fill="none" stroke="{INK}" stroke-width="{sw:.1f}" '
             f'stroke-linejoin="round"/>')
    return "\n".join(o), sil

def icon(framing="tile"):
    S = 1024
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">']
    if framing == "macos":
        m=100; side=S-2*m; rad=185
        parts.append(f'<defs><filter id="sh" x="-40%" y="-40%" width="180%" height="180%">'
                     f'<feDropShadow dx="0" dy="14" stdDeviation="22" flood-color="#000" flood-opacity="0.28"/>'
                     f'</filter></defs>')
        parts.append(f'<g filter="url(#sh)"><rect x="{m}" y="{m}" width="{side}" height="{side}" '
                     f'rx="{rad}" fill="{CREAM}"/></g>')
        cx, cy, Rx = S/2, S/2-side*0.03, side*0.33
    elif framing == "maskable":
        parts.append(f'<rect width="{S}" height="{S}" fill="{CREAM}"/>')
        cx, cy, Rx = S/2, S/2-30, S*0.30
    else:  # tile (web / windows / favicon)
        parts.append(f'<rect width="{S}" height="{S}" rx="150" fill="{CREAM}"/>')
        cx, cy, Rx = S/2, S/2-30, S*0.33
    body, _ = bowl(cx, cy, Rx)
    parts.append(body)
    parts.append('</svg>')
    return "\n".join(parts)

if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for fr in ("tile", "macos", "maskable"):
        open(f"{out}/flat_{fr}.svg", "w").write(icon(fr))
        print("wrote", fr)
