import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/models/units.dart';

void main() {
  group('project persistence', () {
    test('antialias3d and displayUnit round-trip through JSON', () {
      final p = BowlProject.sample()
          .copyWith(displayUnit: LengthUnit.inch, antialias3d: true);
      final back = BowlProject.fromJson(p.toJson());
      expect(back.antialias3d, isTrue);
      expect(back.displayUnit, LengthUnit.inch);
    });

    test('antialias3d defaults to false for older files without the field', () {
      final json = BowlProject.sample().toJson()..remove('antialias3d');
      expect(BowlProject.fromJson(json).antialias3d, isFalse);
    });

    test('per-ring rotationDeg round-trips (null stays auto)', () {
      final p = BowlProject.sample();
      final withRot = p.copyWith(rings: [
        for (var i = 0; i < p.rings.length; i++)
          i == 1 ? p.rings[i].copyWith(rotationDeg: 7.5) : p.rings[i],
      ]);
      final back = BowlProject.fromJson(withRot.toJson());
      expect(back.rings[1].rotationDeg, closeTo(7.5, 1e-9));
      expect(back.rings[0].rotationDeg, isNull); // untouched stays auto
    });
  });
}
