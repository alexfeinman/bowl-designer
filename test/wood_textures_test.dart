import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/material.dart';
import 'package:segmented_bowl_designer/rendering/wood_textures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled wood textures', () {
    const ids = [
      'maple', 'walnut', 'cherry', 'oak', 'ash', 'padauk', 'wenge', 'purpleheart',
    ];

    bool isPow2(int n) => n > 0 && (n & (n - 1)) == 0;

    test('every species image decodes and is a power-of-two square', () async {
      for (final id in ids) {
        final bytes = await rootBundle.load('assets/textures/wood/$id.jpg');
        expect(bytes.lengthInBytes, greaterThan(0), reason: '$id.jpg empty');
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final w = frame.image.width, h = frame.image.height;
        // Mipmaps + REPEAT wrap need power-of-two dims, else the GPU texture is
        // incomplete and samples as garbage. Keep them POT (and square).
        expect(isPow2(w) && isPow2(h), isTrue, reason: '$id is ${w}x$h (not POT)');
        expect(w, h, reason: '$id not square (${w}x$h)');
        frame.image.dispose();
      }
    });

    test('every library wood resolves to a shipped image id', () {
      for (final m in WoodLibrary.all) {
        expect(ids.contains(WoodTextures.assetIdFor(m)), isTrue,
            reason: '${m.id} → ${WoodTextures.assetIdFor(m)}');
      }
    });

    test('unknown material falls back by lightness', () {
      SegmentMaterial m(int argb) =>
          SegmentMaterial(id: 'custom', name: 'x', colorValue: argb);
      expect(WoodTextures.assetIdRaw('custom', 0xFF101010), 'wenge'); // very dark
      expect(WoodTextures.assetIdFor(m(0xFFFFF3E0)), 'maple'); // very light
    });

    test('every shipped species has a true-colour photo (no tint)', () {
      for (final id in ids) {
        expect(WoodTextures.tintFor(id), 0xFFFFFFFF, reason: '$id tinted');
      }
    });
  });
}
