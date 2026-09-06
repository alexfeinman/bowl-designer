#!/usr/bin/env python3
"""Flat, bold-outlined wood UI icon set (24x24). Matches the app-icon style."""
import math, os, sys

INK = "#2b2115"; MAPLE = "#ecd9ac"; OAK = "#c6883a"; WAL = "#6f4a2f"; CREAM = "#f4ecdb"

def svg(inner):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
            f'stroke="{INK}" stroke-width="1.6" stroke-linejoin="round" '
            f'stroke-linecap="round">\n{inner}\n</svg>\n')

def wedge(cx, cy, r, a0, a1):
    x0, y0 = cx + r*math.cos(a0), cy + r*math.sin(a0)
    x1, y1 = cx + r*math.cos(a1), cy + r*math.sin(a1)
    return f'M{cx} {cy} L{x0:.2f} {y0:.2f} A{r} {r} 0 0 1 {x1:.2f} {y1:.2f} Z'

ICONS = {}

# --- bowl (3/4 checkered) ---
ICONS["bowl"] = f'''<defs><clipPath id="bc">
<path d="M3.5 9.4 C4 15 7.6 18.6 12 18.6 C16.4 18.6 20 15 20.5 9.4 Z"/></clipPath></defs>
<g clip-path="url(#bc)" stroke="none">
  <rect x="3" y="6" width="6" height="14" fill="{MAPLE}"/>
  <rect x="9" y="6" width="5" height="14" fill="{WAL}"/>
  <rect x="14" y="6" width="7" height="14" fill="{OAK}"/>
  <rect x="3" y="13" width="6" height="7" fill="{OAK}"/>
  <rect x="14" y="13" width="7" height="7" fill="{MAPLE}"/>
</g>
<path d="M3.5 9.4 C4 15 7.6 18.6 12 18.6 C16.4 18.6 20 15 20.5 9.4"/>
<ellipse cx="12" cy="9.1" rx="8.5" ry="3.1" fill="{CREAM}"/>'''

# --- cube (3D view) ---
ICONS["cube"] = f'''<path d="M12 2.8 L20 7.3 L12 11.8 L4 7.3 Z" fill="{CREAM}"/>
<path d="M4 7.3 L12 11.8 L12 21.2 L4 16.7 Z" fill="{OAK}"/>
<path d="M20 7.3 L12 11.8 L12 21.2 L20 16.7 Z" fill="{WAL}"/>'''

# --- disk (segmented solid, top view) ---
def disk():
    cx=cy=12; r=8.6; n=8; parts=[f'<circle cx="12" cy="12" r="{r}" fill="{MAPLE}"/>']
    parts.append('<g stroke="none">')
    for k in range(n):
        a0=k*2*math.pi/n; a1=(k+1)*2*math.pi/n
        col = WAL if k%2 else OAK
        if k%2:
            parts.append(f'<path d="{wedge(cx,cy,r,a0,a1)}" fill="{col}"/>')
    parts.append('</g>')
    for k in range(n):
        a=k*2*math.pi/n
        parts.append(f'<line x1="12" y1="12" x2="{12+r*math.cos(a):.2f}" y2="{12+r*math.sin(a):.2f}" stroke-width="1"/>')
    parts.append(f'<circle cx="12" cy="12" r="{r}" fill="none"/>')
    parts.append(f'<circle cx="12" cy="12" r="1.7" fill="{CREAM}"/>')
    return "\n".join(parts)
ICONS["disk"] = disk()

# --- ring (torus, top view) ---
def ring():
    cx=cy=12; ro=8.6; ri=4.0; p=[f'<circle cx="12" cy="12" r="{ro}" fill="{OAK}"/>']
    p.append('<g stroke="none">')
    n=6
    for k in range(n):
        if k%2:
            a0=k*2*math.pi/n; a1=(k+1)*2*math.pi/n
            p.append(f'<path d="{wedge(cx,cy,ro,a0,a1)}" fill="{WAL}"/>')
    p.append('</g>')
    for k in range(n):
        a=k*2*math.pi/n
        p.append(f'<line x1="{12+ri*math.cos(a):.2f}" y1="{12+ri*math.sin(a):.2f}" x2="{12+ro*math.cos(a):.2f}" y2="{12+ro*math.sin(a):.2f}" stroke-width="1"/>')
    p.append(f'<circle cx="12" cy="12" r="{ro}" fill="none"/>')
    p.append(f'<circle cx="12" cy="12" r="{ri}" fill="{CREAM}"/>')
    return "\n".join(p)
ICONS["ring"] = ring()

# --- compound (flared frustum, side) ---
ICONS["compound"] = f'''<path d="M7 7.5 L4 16 A8 2.4 0 0 0 20 16 L17 7.5 A5 1.7 0 0 1 7 7.5 Z" fill="{OAK}"/>
<ellipse cx="12" cy="7.5" rx="5" ry="1.7" fill="{CREAM}"/>
<line x1="12" y1="9" x2="12" y2="17.6" stroke-width="1" opacity="0.5"/>'''

# --- stave (two vertical boards) ---
ICONS["stave"] = f'''<rect x="5" y="4.5" width="5.6" height="15" rx="1.1" fill="{WAL}"/>
<line x1="7.8" y1="6" x2="7.8" y2="18" stroke-width="0.9" opacity="0.5"/>
<rect x="13.4" y="4.5" width="5.6" height="15" rx="1.1" fill="{MAPLE}"/>
<line x1="16.2" y1="6" x2="16.2" y2="18" stroke-width="0.9" opacity="0.5"/>'''

def badge(sign):
    b = f'<circle cx="18.5" cy="6" r="4.3" fill="{OAK}"/>'
    b += '<line x1="16.5" y1="6" x2="20.5" y2="6" stroke="#fff" stroke-width="1.7"/>'
    if sign == "+":
        b += '<line x1="18.5" y1="4" x2="18.5" y2="8" stroke="#fff" stroke-width="1.7"/>'
    return b

# --- add_ring / remove_ring ---
_ring_flat = f'''<ellipse cx="10.5" cy="14.5" rx="8" ry="3.2" fill="{MAPLE}"/>
<g stroke="none"><path d="M{10.5+8} 14.5 A8 3.2 0 0 1 {10.5-8} 14.5 L{10.5-3.4} 14.5 A3.4 1.3 0 0 0 {10.5+3.4} 14.5 Z" fill="{OAK}"/></g>
<ellipse cx="10.5" cy="14.5" rx="8" ry="3.2" fill="none"/>
<ellipse cx="10.5" cy="14.5" rx="3.4" ry="1.3" fill="{CREAM}"/>'''
ICONS["add_ring"] = _ring_flat + "\n" + badge("+")
ICONS["remove_ring"] = _ring_flat + "\n" + badge("-")

# --- undo / redo (bold oak curved arrows) ---
ICONS["undo"] = f'''<g stroke="{OAK}" stroke-width="2.3">
<path d="M7.5 9 H14 a4.8 4.8 0 1 1 -4.8 4.8" fill="none"/>
<path d="M8 5 L4 9 L8 13" fill="none"/></g>'''
ICONS["redo"] = f'''<g stroke="{OAK}" stroke-width="2.3">
<path d="M16.5 9 H10 a4.8 4.8 0 1 0 4.8 4.8" fill="none"/>
<path d="M16 5 L20 9 L16 13" fill="none"/></g>'''

# --- dimensions (caliper double-arrow over a small bowl) ---
ICONS["dimensions"] = f'''<path d="M6.5 15 C6.5 18 8.9 19.6 12 19.6 C15.1 19.6 17.5 18 17.5 15" fill="{MAPLE}"/>
<ellipse cx="12" cy="15" rx="5.5" ry="1.9" fill="{CREAM}"/>
<g stroke="{OAK}" stroke-width="1.8">
<line x1="4" y1="7" x2="20" y2="7"/>
<path d="M4 7 L6.4 4.8 M4 7 L6.4 9.2" fill="none"/>
<path d="M20 7 L17.6 4.8 M20 7 L17.6 9.2" fill="none"/></g>'''

# --- cut_list (document) ---
ICONS["cut_list"] = f'''<path d="M6 3 H14 L18.5 7.5 V21 H6 Z" fill="{CREAM}"/>
<path d="M14 3 V7.5 H18.5" fill="none"/>
<rect x="8" y="10.5" width="2.4" height="2.4" fill="{OAK}" stroke-width="0"/>
<rect x="8" y="14.5" width="2.4" height="2.4" fill="{WAL}" stroke-width="0"/>
<line x1="11.4" y1="11.7" x2="16" y2="11.7"/>
<line x1="11.4" y1="15.7" x2="16" y2="15.7"/>'''

# --- lumber (stacked boards) ---
ICONS["lumber"] = f'''<rect x="3.5" y="13.5" width="17" height="4.2" rx="1" fill="{OAK}"/>
<rect x="4.5" y="9.3" width="15" height="4.2" rx="1" fill="{MAPLE}"/>
<rect x="3.8" y="5.1" width="16" height="4.2" rx="1" fill="{WAL}"/>'''

# --- grain (swatch) ---
ICONS["grain"] = f'''<rect x="4" y="4" width="16" height="16" rx="2.6" fill="{MAPLE}"/>
<g stroke="{WAL}" stroke-width="1" fill="none" opacity="0.8">
<path d="M6 8.5 q3 -1.8 6 0 t6 0"/>
<path d="M6 12 q3 -1.8 6 0 t6 0"/>
<path d="M6 15.5 q3 -1.8 6 0 t6 0"/></g>
<ellipse cx="12" cy="12" rx="1.5" ry="1" stroke="{WAL}" stroke-width="1" opacity="0.8"/>'''

# --- rotate (refresh around bowl) ---
ICONS["rotate"] = f'''<g stroke="{OAK}" stroke-width="2.1" fill="none">
<path d="M18.5 8.5 A7 7 0 1 0 19.2 14"/>
</g><path d="M15.4 8.2 L18.9 8.7 L19.4 5.2 L21 9.6 Z" fill="{OAK}" stroke="none"/>
<path d="M9.5 12.5 C9.5 14.4 10.6 15.3 12 15.3 C13.4 15.3 14.5 14.4 14.5 12.5" fill="{MAPLE}"/>
<ellipse cx="12" cy="12.5" rx="2.5" ry="0.9" fill="{CREAM}"/>'''

# --- save (floppy) ---
ICONS["save"] = f'''<path d="M5 4 H15.5 L20 8.5 V19 a1 1 0 0 1 -1 1 H5 a1 1 0 0 1 -1 -1 V5 a1 1 0 0 1 1 -1 Z" fill="{CREAM}"/>
<rect x="7.5" y="4" width="4" height="4" fill="{OAK}" stroke-width="0"/>
<rect x="7" y="12.5" width="10" height="6" rx="0.8" fill="{MAPLE}"/>
<line x1="9" y1="15" x2="15" y2="15" stroke-width="1"/>
<path d="M5 4 H15.5 L20 8.5 V19 a1 1 0 0 1 -1 1 H5 a1 1 0 0 1 -1 -1 V5 a1 1 0 0 1 1 -1 Z" fill="none"/>'''


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, inner in ICONS.items():
        open(os.path.join(out, f"{name}.svg"), "w").write(svg(inner))
    print(f"wrote {len(ICONS)} icons to {out}")
    print(" ".join(sorted(ICONS)))
