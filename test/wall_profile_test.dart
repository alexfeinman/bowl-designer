import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/geometry/wall_profile.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';

void main() {
  group('finished wall profile', () {
    final project = BowlProject.sample();

    test('samples span the full height and stay ordered/inside outer', () {
      final p = computeWallProfile(project, samples: 100);
      expect(p.ys.first, 0.0);
      expect(p.ys.last, closeTo(project.totalHeightMm, 1e-6));
      for (var i = 0; i < p.ys.length; i++) {
        expect(p.innerR[i], lessThanOrEqualTo(p.outerR[i] + 1e-6));
        expect(p.innerR[i], greaterThanOrEqualTo(-1e-9));
      }
    });

    test('uniform wall: floor stays solid, walls hold the target thickness', () {
      const wall = 8.0;
      final p = computeWallProfile(project, wallMm: wall, samples: 200);

      // Inside the bottom course (below the floor top) the bore is closed.
      for (var i = 0; i < p.ys.length; i++) {
        if (p.ys[i] < p.baseTopY - 1) {
          expect(p.innerR[i], closeTo(0.0, 1e-6),
              reason: 'floor should be solid at y=${p.ys[i]}');
        }
      }

      // Above the floor the wall never exceeds the target (it can only be
      // thinner where the glued bore is already wider than outer - wall).
      for (var i = 0; i < p.ys.length; i++) {
        if (p.ys[i] > p.baseTopY + 1 && p.innerR[i] > 0.01) {
          expect(p.outerR[i] - p.innerR[i], lessThanOrEqualTo(wall + 1e-6));
        }
      }

      // Near the rim the target wall is achievable, so it holds.
      final top = p.ys.length - 1;
      expect(p.outerR[top] - p.innerR[top], closeTo(wall, 0.5));
    });

    test('a thinner wall bores further in than a thicker one at the rim', () {
      final thin = computeWallProfile(project, wallMm: 5, samples: 120);
      final thick = computeWallProfile(project, wallMm: 12, samples: 120);
      final i = thin.ys.length - 1;
      expect(thin.innerR[i], greaterThan(thick.innerR[i]));
    });
  });
}
