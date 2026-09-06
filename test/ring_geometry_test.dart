import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/geometry/ring_geometry.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/models/ring.dart';

void main() {
  group('miter angle', () {
    test('180 / n', () {
      expect(RingGeometry.miterAngleDeg(12), closeTo(15.0, 1e-9));
      expect(RingGeometry.miterAngleDeg(16), closeTo(11.25, 1e-9));
      expect(RingGeometry.miterAngleDeg(8), closeTo(22.5, 1e-9));
    });
    test('single segment has no miter', () {
      expect(RingGeometry.miterAngleDeg(1), 0.0);
    });
  });

  group('edge length = 2 r tan(halfSpan)', () {
    test('12 segments, OD 180 -> outer edge ~48.23mm', () {
      expect(RingGeometry.edgeLength(90, math.pi / 12), closeTo(48.231, 0.01));
    });
    test('8 segments, OD 200 -> outer edge ~82.84mm', () {
      expect(RingGeometry.edgeLength(100, math.pi / 8), closeTo(82.843, 0.01));
    });
    test('zero radius (disk inner edge) -> 0', () {
      expect(RingGeometry.edgeLength(0, math.pi / 12), 0.0);
    });
  });

  group('cut spec', () {
    test('normal ring computes edges, wall and miter', () {
      final ring = Ring(
        id: 'r',
        name: 'C',
        type: RingType.normal,
        outerDiameter: 220,
        innerDiameter: 170,
        thickness: 25,
        segmentCount: 16,
      );
      final s = RingGeometry.cutSpec(ring, kerfAllowanceMm: 6);
      expect(s.solid, isFalse);
      expect(s.physicalSegments, 16);
      expect(s.miterAngleDeg, closeTo(11.25, 1e-9));
      expect(s.wallWidthMm, closeTo(25.0, 1e-9));
      expect(s.outerEdgeMm, closeTo(RingGeometry.edgeLength(110, math.pi / 16), 1e-9));
      expect(s.innerEdgeMm, closeTo(RingGeometry.edgeLength(85, math.pi / 16), 1e-9));
      expect(s.boardLengthMm, closeTo(16 * (s.outerEdgeMm + 6), 1e-9));
      expect(s.boardFeet, greaterThan(0));
    });

    test('disk with one segment is solid, no miter, no hole', () {
      final ring = Ring(
        id: 'd',
        name: 'Base',
        type: RingType.disk,
        outerDiameter: 130,
        innerDiameter: 0,
        thickness: 19,
        segmentCount: 1,
      );
      final s = RingGeometry.cutSpec(ring);
      expect(s.solid, isTrue);
      expect(s.physicalSegments, 1);
      expect(s.miterAngleDeg, 0.0);
      expect(s.innerEdgeMm, 0.0);
      expect(s.outerEdgeMm, 130.0);
    });

    test('segmented disk (n>1) has miters and 0 inner edge', () {
      final ring = Ring(
        id: 'd',
        name: 'Base',
        type: RingType.disk,
        outerDiameter: 130,
        innerDiameter: 0,
        thickness: 19,
        segmentCount: 12,
      );
      final s = RingGeometry.cutSpec(ring);
      expect(s.solid, isFalse);
      expect(s.miterAngleDeg, closeTo(15.0, 1e-9));
      expect(s.innerEdgeMm, 0.0);
      expect(s.physicalSegments, 12);
    });

    test('gap keeps count and does not change miter (segments are spaced)', () {
      Ring ringWith(double gap) => Ring(
            id: 'r',
            name: 'C',
            type: RingType.normal,
            outerDiameter: 200,
            innerDiameter: 160,
            thickness: 20,
            segmentCount: 12,
            gapMm: gap,
          );
      final closed = RingGeometry.cutSpec(ringWith(0));
      final open = RingGeometry.cutSpec(ringWith(6));
      expect(open.physicalSegments, 12); // gaps don't remove segments
      expect(open.miterAngleDeg, closeTo(closed.miterAngleDeg, 1e-9));
      expect(closed.miterAngleDeg, closeTo(15.0, 1e-9)); // classic 180/n

      // A flat gap trims both ends of each segment, so the edges get shorter:
      // gapMm / cos(pi/n) off the outer and inner edge alike.
      final trim = 6 / math.cos(math.pi / 12);
      expect(open.outerEdgeMm, closeTo(closed.outerEdgeMm - trim, 1e-9));
      expect(open.innerEdgeMm, closeTo(closed.innerEdgeMm - trim, 1e-9));
      expect(open.outerEdgeMm, lessThan(closed.outerEdgeMm));
    });
  });

  group('compound ring', () {
    Ring compound(double angle) => Ring(
          id: 'r',
          name: 'C',
          type: RingType.compound,
          outerDiameter: 200,
          innerDiameter: 160,
          thickness: 20,
          segmentCount: 12,
          wallAngle: angle,
        );

    test('flat (0°) matches a normal ring; adds no bevel', () {
      final s = RingGeometry.cutSpec(compound(0));
      expect(s.miterAngleDeg, closeTo(15.0, 1e-9));
      expect(s.bevelAngleDeg, 0.0);
      expect(s.stave, isFalse);
      expect(s.outerEdgeMm,
          closeTo(RingGeometry.edgeLength(100, math.pi / 12), 1e-9));
    });

    test('wall angle tilts the wall and becomes the blade bevel', () {
      final r = compound(15);
      // Base OD is stored; the wall flares outward by thickness·tan(angle).
      final rise = 20 * math.tan(15 * math.pi / 180);
      expect(r.wallRiseMm, closeTo(rise, 1e-9));
      expect(r.topOuterDiameter, closeTo(200 + 2 * rise, 1e-9));
      final s = RingGeometry.cutSpec(r);
      expect(s.miterAngleDeg, closeTo(15.0, 1e-9)); // fence miter unchanged
      expect(s.bevelAngleDeg, closeTo(15.0, 1e-9)); // blade tilt = wall angle
      // Edge is taken at the mid-height radius (base radius + rise/2).
      expect(s.outerEdgeMm,
          closeTo(RingGeometry.edgeLength(100 + rise / 2, math.pi / 12), 1e-9));
    });
  });

  group('stave ring', () {
    Ring stave(double angle) => Ring(
          id: 'r',
          name: 'Rim',
          type: RingType.stave,
          outerDiameter: 200,
          innerDiameter: 170,
          thickness: 60, // tall board
          segmentCount: 12,
          wallAngle: angle,
        );

    test('straight tube: rip bevel = 180/n, no miter, length = height', () {
      final s = RingGeometry.cutSpec(stave(0));
      expect(s.stave, isTrue);
      expect(s.miterAngleDeg, 0.0);
      expect(s.bevelAngleDeg, closeTo(15.0, 1e-9)); // 180/12
      expect(s.endBevelDeg, 0.0);
      expect(s.thicknessMm, closeTo(60, 1e-9)); // stave length = height
      expect(s.outerEdgeMm,
          closeTo(RingGeometry.edgeLength(100, math.pi / 12), 1e-9)); // width
      expect(s.boardLengthMm, closeTo(12 * (60 + 6), 1e-9)); // n·(len+kerf)
    });

    test('tapered: flares outward, compound edge bevel, back-beveled ends', () {
      final r = stave(15);
      expect(r.wallRiseMm, greaterThan(0));
      expect(r.topOuterDiameter, greaterThan(r.outerDiameter));
      final s = RingGeometry.cutSpec(r);
      // atan(cos15·tan15) < 15: the taper eases the rip bevel below 180/n.
      expect(s.bevelAngleDeg, lessThan(15.0));
      expect(s.bevelAngleDeg,
          closeTo(RingGeometry.staveBevelDeg(12, 15 * math.pi / 180), 1e-9));
      expect(s.endBevelDeg, closeTo(15.0, 1e-9));
    });
  });

  group('auto-fit walls', () {
    final project = BowlProject.sample();

    test('follow profile makes every ring wall == target', () {
      final fitted = RingGeometry.autoAdjustWalls(project, 8, WallFitMode.followProfile);
      for (final r in fitted.rings) {
        if (r.type == RingType.disk) {
          expect(r.effectiveInnerDiameter, 0.0);
        } else {
          expect(r.width, closeTo(8.0, 1e-9));
        }
      }
    });

    test('vertical wall gives all walled rings the same bore', () {
      final fitted = RingGeometry.autoAdjustWalls(project, 8, WallFitMode.verticalWall);
      final bores = fitted.rings
          .where((r) => r.type != RingType.disk)
          .map((r) => r.innerDiameter)
          .toSet();
      expect(bores.length, 1);
      // The narrowest walled ring keeps the target wall.
      final narrowest = fitted.rings
          .where((r) => r.type != RingType.disk)
          .reduce((a, b) => a.outerDiameter < b.outerDiameter ? a : b);
      expect(narrowest.width, closeTo(8.0, 1e-6));
    });
  });
}
