import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/rendering/unrolled_painter.dart';

void main() {
  group('unrolled segment map hit-testing', () {
    final project = BowlProject.sample();
    const size = Size(800, 600);
    const padBottom = 60.0;
    final baseY = size.height - padBottom;
    final midX = size.width / 2;

    test('the band nearest the base resolves to the bottom ring', () {
      final id = UnrolledPainter.ringIdAt(project, size, Offset(midX, baseY - 1));
      expect(id, project.rings.first.id);
    });

    test('walking up the stack visits every ring bottom → top', () {
      final totalH = project.totalHeightMm;
      final scaleY = (size.height - 40 - padBottom) / totalH;
      var y = baseY;
      for (final ring in project.rings) {
        final mid = y - ring.thickness * scaleY / 2;
        final id = UnrolledPainter.ringIdAt(project, size, Offset(midX, mid));
        expect(id, ring.id, reason: 'band centre should hit ${ring.name}');
        y -= ring.thickness * scaleY;
      }
    });

    test('clicks in the left gutter and above the stack miss', () {
      // Far left of the chart gutter.
      expect(UnrolledPainter.ringIdAt(project, size, Offset(10, baseY - 1)),
          isNull);
      // Above the topmost band (in the top padding).
      expect(UnrolledPainter.ringIdAt(project, size, const Offset(400, 5)),
          isNull);
    });

    test('degenerate size yields no hit', () {
      expect(
          UnrolledPainter.ringIdAt(project, const Size(0, 0), Offset.zero),
          isNull);
    });
  });
}
