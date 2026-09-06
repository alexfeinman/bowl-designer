import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:three_js/three_js.dart' as three;

import '../models/material.dart';

/// Decoded RGBA pixels for one species image (renderer-independent).
class DecodedWood {
  DecodedWood(this.data, this.width, this.height);
  final three.Uint8Array data;
  final int width;
  final int height;
}

/// Loads the bundled per-species wood-grain textures (CC0 diffuse maps under
/// `assets/textures/wood/`, see CREDITS.md).
///
/// IMPORTANT: only the *decoded pixels* are cached here (app-lifetime,
/// renderer-independent). The actual [three.Texture] must be built per 3D-view
/// instance via [makeTexture] and disposed with that view — a WebGL texture is
/// tied to the renderer/GL context that uploaded it, and the 3D view's renderer
/// is torn down and recreated every time you leave and re-enter the 3D tab. A
/// texture shared across those renderers would sample freed GPU memory (garish
/// noise) on the second visit.
class WoodTextures {
  WoodTextures._();

  /// Species ids that ship with a dedicated grain image.
  static const Set<String> _known = {
    'maple', 'walnut', 'cherry', 'oak', 'ash', 'padauk', 'wenge', 'purpleheart',
  };

  /// A render-time colour tint (ARGB) multiplied over the photo when grain is on.
  /// Every species now has a true-colour photo, so all tints are white; this
  /// stays as the hook for any future reused/neutral grain (see CREDITS.md).
  static const Map<String, int> _tint = {};

  static final Map<String, DecodedWood> _pixels = {};
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

  /// The colour to give a textured mesh's material (`material.color`).
  static int tintFor(String assetId) => _tint[assetId] ?? 0xFFFFFFFF;

  /// Decoded pixels for [assetId], or null if not yet loaded.
  static DecodedWood? pixels(String assetId) => _pixels[assetId];

  /// Ensure every id in [ids] is decoded, invoking [onLoaded] after each newly
  /// finished decode so the caller can build its texture and re-render.
  static void ensure(Iterable<String> ids, void Function() onLoaded) {
    for (final id in ids) {
      if (_pixels.containsKey(id) || _loading.contains(id)) continue;
      _loading.add(id);
      _decode(id).then((d) {
        _loading.remove(id);
        if (d != null) {
          _pixels[id] = d;
          onLoaded();
        }
      });
    }
  }

  /// Build a fresh [three.Texture] from already-decoded pixels, or null if the
  /// pixels aren't loaded yet. The caller owns and must dispose the result.
  static three.Texture? makeTexture(String assetId) {
    final d = _pixels[assetId];
    if (d == null) return null;
    final tex = three.DataTexture(d.data, d.width, d.height, three.RGBAFormat);
    tex.wrapS = three.RepeatWrapping;
    tex.wrapT = three.RepeatWrapping;
    // No mipmaps: flutter_angle does not reliably build a mipmap chain for a
    // DataTexture, so a mipmap minFilter leaves the texture GPU-incomplete and
    // minified surfaces (a bowl's floor centre, a razor-thin wall seen edge-on)
    // sample as RGB static. Linear min/mag on the base level is always complete —
    // it only shimmers a little at extreme minification, never turns to noise.
    tex.magFilter = three.LinearFilter;
    tex.minFilter = three.LinearFilter;
    tex.generateMipmaps = false;
    tex.anisotropy = 1;
    tex.colorSpace = three.SRGBColorSpace;
    tex.flipY = false;
    tex.needsUpdate = true;
    return tex;
  }

  static Future<DecodedWood?> _decode(String assetId) async {
    try {
      final bytes = await rootBundle.load('assets/textures/wood/$assetId.jpg');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = img.width, h = img.height;
      img.dispose();
      if (rgba == null) return null;
      return DecodedWood(
          three.Uint8Array.fromList(rgba.buffer.asUint8List()), w, h);
    } catch (_) {
      return null; // missing/broken asset → silently fall back to flat colour
    }
  }
}
