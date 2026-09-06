# Wood grain textures

Seamless diffuse maps from **Poly Haven** (https://polyhaven.com), all licensed
**CC0 1.0 (public domain)** — free to use, no attribution required. Credited here
as a courtesy. Downloaded as 1K JPG diffuse maps and downscaled to 512×512.

| File              | Poly Haven asset            | Used for                    |
|-------------------|-----------------------------|-----------------------------|
| `maple.jpg`       | `white_maple_veneer`        | Hard maple                  |
| `walnut.jpg`      | `black_walnut_veneer_01`    | Black walnut                |
| `cherry.jpg`      | `cherry_veneer`             | Cherry                      |
| `oak.jpg`         | `white_oak_veneer`          | White oak                   |
| `ash.jpg`         | `ash_veneer`                | Ash                         |
| `padauk.jpg`      | `red_oak_veneer`            | Padauk (warmed by a tint)   |
| `wenge.jpg`       | `black_oak_veneer`          | Wenge                       |
| `purpleheart.jpg` | `ash_veneer`                | Purpleheart (purple tint)   |

Exotic species with no CC0 photographic match (padauk, wenge, purpleheart) reuse
the closest available grain and are shifted to the right hue with a per-species
colour tint applied at render time (see `wood_textures.dart`).
