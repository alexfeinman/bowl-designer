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

    test('every species image is present and decodes to a real bitmap', () async {
      for (final id in ids) {
        final bytes = await rootBundle.load('assets/textures/wood/$id.jpg');
        expect(bytes.lengthInBytes, greaterThan(0), reason: '$id.jpg empty');
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
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

    test('true-match species are untinted; reused exotics carry a tint', () {
      expect(WoodTextures.tintFor('maple'), 0xFFFFFFFF);
      expect(WoodTextures.tintFor('walnut'), 0xFFFFFFFF);
      expect(WoodTextures.tintFor('padauk'), isNot(0xFFFFFFFF));
      expect(WoodTextures.tintFor('purpleheart'), isNot(0xFFFFFFFF));
    });
  });
}
