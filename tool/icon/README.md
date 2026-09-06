# App icon

Source of truth for the application icon: a top-down segmented turned bowl in the
app's warm wood palette (amber rim, brick-bonded maple/walnut courses with a
padauk accent ring, concave shading) on an espresso ground.

- `gen_icon.py` generates the three SVG variants (annular-sector geometry):
  - `icon_macos.svg` — padded squircle + drop shadow (macOS style)
  - `icon_web.svg` — full-bleed rounded square (web icons, favicon, Windows .ico)
  - `icon_maskable.svg` — full-bleed ground, art within the 80% safe zone (PWA)

## Regenerate

Needs `rsvg-convert` and ImageMagick (`magick`). Render native 1024 then downscale
(this rsvg-convert clips with -w/-h, so always render at the SVG's natural size):

```bash
cd tool/icon && python3 gen_icon.py .
rsvg-convert icon_macos.svg    -o m.png
rsvg-convert icon_web.svg      -o w.png
rsvg-convert icon_maskable.svg -o k.png
MAC=../../macos/Runner/Assets.xcassets/AppIcon.appiconset
cp m.png "$MAC/app_icon_1024.png"
for s in 16 32 64 128 256 512; do magick m.png -resize ${s}x${s} "$MAC/app_icon_${s}.png"; done
magick w.png -resize 192x192 ../../web/icons/Icon-192.png
magick w.png -resize 512x512 ../../web/icons/Icon-512.png
magick k.png -resize 192x192 ../../web/icons/Icon-maskable-192.png
magick k.png -resize 512x512 ../../web/icons/Icon-maskable-512.png
magick w.png -resize 32x32   ../../web/favicon.png
magick w.png -define icon:auto-resize=256,128,64,48,32,16 ../../windows/runner/resources/app_icon.ico
rm m.png w.png k.png
```
