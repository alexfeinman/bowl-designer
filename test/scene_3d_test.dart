import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/rendering/scene_3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3D z-buffer rasterizer', () {
    test('renders the sample from several camera angles without throwing',
        () async {
      final project = BowlProject.sample();
      for (final cam in const [
        Camera3D(),
        Camera3D(yaw: 2.1, pitch: -0.9, zoom: 1.6),
        Camera3D(yaw: -1.2, pitch: 1.3, zoom: 3.0),
      ]) {
        final r = await rasterizeScene(project, cam, const ui.Size(400, 300),
            highlightRingIndex: 1);
        expect(r, isNotNull);
        expect(r!.image.width, greaterThan(0));
        r.dispose();
      }
    });

    test('antialiased render supersamples then downsamples to the target size',
        () async {
      final project = BowlProject.sample();
      final plain = await rasterizeScene(
          project, const Camera3D(), const ui.Size(200, 150),
          pixelRatio: 1);
      final aa = await rasterizeScene(
          project, const Camera3D(), const ui.Size(200, 150),
          pixelRatio: 1, antialias: true);
      // Same displayed dimensions; AA just renders at higher internal res.
      expect(aa!.image.width, plain!.image.width);
      expect(aa.image.height, plain.image.height);
      plain.dispose();
      aa.dispose();
    });

    test('hit-test maps a pixel to a ring or empty space', () async {
      final project = BowlProject.sample();
      final r = await rasterizeScene(
          project, const Camera3D(), const ui.Size(400, 300));
      final idx = r!.ringIndexAt(const ui.Offset(200, 150), const ui.Size(400, 300));
      expect(idx == null || (idx >= 0 && idx < project.rings.length), isTrue);
      r.dispose();
    });
  });
}
