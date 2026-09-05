import 'dart:math' as math;

import '../models/bowl_project.dart';
import '../models/ring.dart';

/// How the Auto-fit tool distributes wall thickness.
enum WallFitMode {
  /// Each ring's wall equals the target — the inside mirrors the outer profile.
  followProfile,

  /// A single straight interior bore sized so the narrowest ring keeps the
  /// target wall; wider rings end up thicker.
  verticalWall,
}

/// Computed shop numbers for one ring, all lengths in canonical millimetres.
class RingCutSpec {
  const RingCutSpec({
    required this.ring,
    required this.physicalSegments,
    required this.miterAngleDeg,
    required this.outerEdgeMm,
    required this.innerEdgeMm,
    required this.wallWidthMm,
    required this.thicknessMm,
    required this.boardLengthMm,
    required this.boardFeet,
    required this.solid,
  });

  final Ring ring;
  final int physicalSegments;

  /// Miter angle set on the saw for each end of a segment (0 when solid).
  final double miterAngleDeg;
  final double outerEdgeMm;
  final double innerEdgeMm;
  final double wallWidthMm;
  final double thicknessMm;

  /// Total strip length needed for this ring including the kerf allowance.
  final double boardLengthMm;
  final double boardFeet;
  final bool solid;
}

/// Pure geometry: the single source of truth used by every view and the cut
/// list. No Flutter imports — trivially unit-testable.
class RingGeometry {
  const RingGeometry._();

  static const double _mmPerInch = 25.4;

  /// Miter angle (per end) for a ring of [n] segments with no gap: 180° / n.
  static double miterAngleDeg(int n) => n <= 1 ? 0.0 : 180.0 / n;

  /// Central angle subtended by one segment: 360° / n.
  static double segmentAngleDeg(int n) => n <= 0 ? 0.0 : 360.0 / n;

  /// Angular half-width (radians) of a segment: π / n. A gap does not change
  /// the miter — segments are cut normally and spaced apart by a flat slot.
  static double halfSpanRad(Ring ring) =>
      ring.segmentCount <= 1 ? 0.0 : math.pi / ring.segmentCount;

  /// Miter angle (per end, degrees) for [ring]: 180 / n (gap-independent).
  static double miterForRing(Ring ring) =>
      ring.isSolid ? 0.0 : 180.0 / ring.segmentCount;

  /// Flat edge length of a segment at radius [radiusMm] given a half-span.
  static double edgeLength(double radiusMm, double halfSpan) {
    if (halfSpan <= 0 || radiusMm <= 0) return 0.0;
    return 2 * radiusMm * math.tan(halfSpan);
  }

  /// Full shop specification for a single [ring].
  static RingCutSpec cutSpec(Ring ring, {double kerfAllowanceMm = 6.0}) {
    final solid = ring.isSolid;
    final ro = ring.outerDiameter / 2.0;
    final ri = ring.effectiveInnerDiameter / 2.0;
    final physical = ring.physicalSegmentCount;
    final halfSpan = halfSpanRad(ring);

    final outerEdge = solid ? ring.outerDiameter : edgeLength(ro, halfSpan);
    final innerEdge = solid ? 0.0 : edgeLength(ri, halfSpan);
    final wall = ring.width;

    final boardLength = physical * (outerEdge + kerfAllowanceMm);

    // Bounding-board volume per segment, summed, expressed in board-feet
    // (1 board-foot = 144 in³).
    final segVolIn3 = (outerEdge / _mmPerInch) *
        (wall / _mmPerInch) *
        (ring.thickness / _mmPerInch);
    final boardFeet = physical * segVolIn3 / 144.0;

    return RingCutSpec(
      ring: ring,
      physicalSegments: physical,
      miterAngleDeg: miterForRing(ring),
      outerEdgeMm: outerEdge,
      innerEdgeMm: innerEdge,
      wallWidthMm: wall,
      thicknessMm: ring.thickness,
      boardLengthMm: boardLength,
      boardFeet: boardFeet,
      solid: solid,
    );
  }

  /// Cut specs for every ring in [project], bottom to top.
  static List<RingCutSpec> cutList(BowlProject project) => [
        for (final r in project.rings)
          cutSpec(r, kerfAllowanceMm: project.kerfAllowanceMm),
      ];

  /// Total board-feet across the whole project.
  static double totalBoardFeet(BowlProject project) =>
      cutList(project).fold(0.0, (a, s) => a + s.boardFeet);

  /// Return a new project whose inner diameters are recomputed for a uniform
  /// finished wall of [targetWallMm], using [mode]. Disks keep ID = 0.
  static BowlProject autoAdjustWalls(
    BowlProject project,
    double targetWallMm,
    WallFitMode mode,
  ) {
    if (project.rings.isEmpty) return project;

    double? bore;
    if (mode == WallFitMode.verticalWall) {
      // Bore sized so the narrowest non-disk ring keeps the target wall.
      final walled = project.rings.where((r) => r.type != RingType.disk);
      if (walled.isNotEmpty) {
        final minOd = walled.map((r) => r.outerDiameter).reduce(math.min);
        bore = math.max(0.0, minOd - 2 * targetWallMm);
      }
    }

    final newRings = [
      for (final r in project.rings)
        if (r.type == RingType.disk)
          r.copyWith(innerDiameter: 0)
        else
          r.copyWith(
            innerDiameter: switch (mode) {
              WallFitMode.followProfile =>
                math.max(0.0, r.outerDiameter - 2 * targetWallMm),
              WallFitMode.verticalWall =>
                (bore ?? math.max(0.0, r.outerDiameter - 2 * targetWallMm))
                    .clamp(0.0, r.outerDiameter),
            },
          ),
    ];

    return project.copyWith(rings: newRings, targetWallMm: targetWallMm);
  }
}
