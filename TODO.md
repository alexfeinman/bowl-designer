# TODO

## Done
1. ✅ 3D view: clicking empty space hides the highlight locally (ring-list selection kept); selecting any ring (list or 3D) re-shows it.
2. ✅ Editing a ring attribute no longer resets the 3D camera — the mesh rebuilds in place. (Reset view still reframes.)
3. ✅ 3D renders on demand instead of every frame, so an idle view uses no GPU/CPU — fixes the Linux all-cores hang (software-GL fallback) and saves battery. *Fix verified on web/macOS; please confirm on the affected Linux box.*
4. ✅ Material pattern rows have reorder drag handles, like the ring stack.
5. ✅ X-ray: a finished-wall-thickness control previews a uniform turned wall on every course except the bottom (the floor).
6. ✅ 3D "Show turned" toggle renders the finished (turned) bowl — the wireframe wall revolved — sharing the X-ray wall setting so the two previews match.
7. ✅ Photorealistic wood grain: a Settings "Wood grain" toggle (persisted on the project) overlays photographic per-species grain on the 3D bowl. Bundled CC0 diffuse maps (Poly Haven) per species; exotics without a CC0 match reuse the closest grain + a hue tint. Geometry buckets by (ring, species) with world-mm UVs (grain scaled to real segment size); textures decoded from assets → DataTexture, shared/cached. Works on the glued-rings and turned-bowl views.
