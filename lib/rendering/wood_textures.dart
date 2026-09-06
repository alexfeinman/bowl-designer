import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:three_js/three_js.dart' as three;

import '../models/material.dart';

/// Loads and caches the bundled per-species wood-grain textures (CC0 diffuse
/// maps under `assets/textures/wood/`, see CREDITS.md) and applies them to the
/// 3D bowl.
///
/// Textures are decoded from the asset bundle to raw RGBA and wrapped in a
/// [three.DataTexture] — this works identically on web and desktop and sidesteps
/// three_js's URL loaders and the deploy's `--base-href`. They are cached for the
/// app's lifetime and shared across every mesh, so callers must **not** dispose
/// them (and must detach a texture from a material — set `mat.map = null` —
/// before disposing that material, since [three.Material.dispose] disposes its
/// `map`).
class WoodTextures {
  WoodTextures._();

  /// Species ids that ship with a dedicated grain image.
  static const Set<String> _known = {
    'maple', 'walnut', 'cherry', 'oak', 'ash', 'padauk', 'wenge', 'purpleheart',
  };

  /// A render-time colour tint (ARGB) multiplied over the photo when grain is on.
  /// Every shipped species now has a true-colour photo, so all tints are white;
  /// this stays as the hook for any future reused/neutral grain (see CREDITS.md).
  static const Map<String, int> _tint = {};

  static final Map<String, three.Texture> _cache = {};
  static final Set<String> _loading = {};

  /// The image asset id to use for a material: its own id when we ship that
  /// species, otherwise the nearest match chosen by colour lightness.
  static String assetIdFor(SegmentMaterial m) => assetIdRaw(m.id, m.colorValue);

  /// As [assetIdFor], from a raw id + ARGB (the 3D meshes carry only these).
  static String assetIdRaw(String id, int argb) {
    if (_known.contains(id)) return id;
    final r = ((argb >> 16) & 0xff) / 255.0;
    final g = ((argb >> 8) & 0xff) / 255.0;
    final b = (argb & 0xff) / 255.0;
    final lum = 0.299 * r + 0.587 * g + 0.114 * b; // 0..1
    if (lum < 0.28) return 'wenge';
    if (lum < 0.5) return 'walnut';
    if (lum < 0.72) return 'oak';
    return 'maple';
  }

  /// The colour to give a textured mesh's material (`material.color`). Grain is
  /// multiplied by this, so it stays white for true-match species and tints the
  /// reused exotics. Unknown/custom materials show their nearest photo untinted.
  static int tintFor(String assetId) => _tint[assetId] ?? 0xFFFFFFFF;

  /// A texture that is already decoded, or null if it still needs loading.
  static three.Texture? cached(String assetId) => _cache[assetId];

  /// Ensure every id in [ids] is decoded, invoking [onLoaded] once after each
  /// newly-finished load so the caller can attach the map and re-render.
  static void ensure(Iterable<String> ids, void Function() onLoaded) {
    for (final id in ids) {
      if (_cache.containsKey(id) || _loading.contains(id)) continue;
      _loading.add(id);
      _load(id).then((tex) {
        _loading.remove(id);
        if (tex != null) {
          _cache[id] = tex;
          onLoaded();
        }
      });
    }
  }

  static Future<three.Texture?> _load(String assetId) async {
    try {
      final bytes = await rootBundle.load('assets/textures/wood/$assetId.jpg');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;
      final w = img.width, h = img.height;
      final data = rgba.buffer.asUint8List();
      img.dispose();

      final tex = three.DataTexture(
          three.Uint8Array.fromList(data), w, h, three.RGBAFormat);
      tex.wrapS = three.RepeatWrapping;
      tex.wrapT = three.RepeatWrapping;
      tex.magFilter = three.LinearFilter;
      tex.minFilter = three.LinearMipmapLinearFilter;
      tex.generateMipmaps = true;
      tex.anisotropy = 8;
      tex.colorSpace = three.SRGBColorSpace;
      tex.flipY = false;
      tex.needsUpdate = true;
      return tex;
    } catch (_) {
      return null; // missing/broken asset → silently fall back to flat colour
    }
  }
}
