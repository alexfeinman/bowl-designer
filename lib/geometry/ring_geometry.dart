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
    required this.bevelAngleDeg,
    required this.endBevelDeg,
    required this.outerEdgeMm,
    required this.innerEdgeMm,
    required this.wallWidthMm,
    required this.thicknessMm,
    required this.boardLengthMm,
    required this.boardFeet,
    required this.solid,
    required this.stave,
  });

  final Ring ring;
  final int physicalSegments;

  /// Miter angle set on the saw fence for each end of a flat wedge segment
  /// (180/n). Zero when solid, or for staves (whose joints are rip bevels).
  final double miterAngleDeg;

  /// Blade-tilt bevel. For a compound ring it is the wall tilt applied to the
  /// wedge faces; for a stave it is the rip bevel along each long edge
  /// (180/n straight, a compound value when tapered). Zero for flat rings.
  final double bevelAngleDeg;

  /// Back-bevel cut on the ends of a tapered stave so it seats flat; 0 for a
  /// straight tube and for non-stave rings.
  final double endBevelDeg;

  /// For flat wedges: the flat cut length at the outer/inner radius. For a
  /// stave: the outer/inner WIDTH of the board.
  final double outerEdgeMm;
  final double innerEdgeMm;
  final double wallWidthMm;

  /// For flat wedges: the course height. For a stave: the length of the board
  /// (which is the course height).
  final double thicknessMm;

  /// Total strip length needed for this ring including the kerf allowance:
  /// n·(outer edge + kerf) for wedges, n·(stave length + kerf) for staves.
  final double boardLengthMm;
  final double boardFeet;
  final bool solid;

  /// True when this course is built from vertical staves (barrel style) rather
  /// than flat-laid wedges, so views/exports can relabel its columns.
  final bool stave;
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

  /// Rip-bevel per long edge (degrees) for a staved course of [n] staves whose
  /// wall tilts [tiltRad] from vertical. Straight (tilt 0): 180/n. As the wall
  /// approaches horizontal the bevel tends to 0 (a flat disk needs no rip
  /// bevel). bevel = atan(cos(tilt)·tan(π/n)).
  static double staveBevelDeg(int n, double tiltRad) {
    if (n <= 1) return 0.0;
    return math.atan(math.cos(tiltRad) * math.tan(math.pi / n)) * 180.0 / math.pi;
  }

  /// Flat edge length of a segment at radius [radiusMm] given a half-span,
  /// with no gap: 2·r·tan(halfSpan) — the circumscribed polygon side.
  static double edgeLength(double radiusMm, double halfSpan) {
    if (halfSpan <= 0 || radiusMm <= 0) return 0.0;
    return 2 * radiusMm * math.tan(halfSpan);
  }

  /// Flat edge length at radius [radiusMm] once a flat gap of [gapMm] is left
  /// between adjacent segments. The gap is a parallel slot, so each glue face
  /// moves in by gapMm/2 and trims gapMm/(2·cos(halfSpan)) off each end of the
  /// edge — i.e. gapMm/cos(halfSpan) total. Never returns below zero.
  static double edgeLengthWithGap(double radiusMm, double halfSpan, double gapMm) {
    final full = edgeLength(radiusMm, halfSpan);
    if (full <= 0) return 0.0;
    if (gapMm <= 0) return full;
    return math.max(0.0, full - gapMm / math.cos(halfSpan));
  }

  /// Full shop specification for a single [ring].
  static RingCutSpec cutSpec(Ring ring, {double kerfAllowanceMm = 6.0}) {
    final solid = ring.isSolid;
    final physical = ring.physicalSegmentCount;
    final halfSpan = halfSpanRad(ring);
    final wall = ring.width;
    final tilt = ring.wallTiltRad; // 0 unless compound / tapered stave
    // Edge lengths taken at the course mid-height radius (the flare grows the
    // radius over the height; the middle is representative for the flat cut).
    final rMeanO = ring.outerDiameter / 2.0 + ring.wallRiseMm / 2.0;
    final rMeanI = ring.effectiveInnerDiameter <= 0
        ? 0.0
        : ring.effectiveInnerDiameter / 2.0 + ring.wallRiseMm / 2.0;

    if (ring.type == RingType.stave && !solid) {
      // Vertical boards. Outer/inner "edge" is the stave WIDTH; the piece
      // length is the course height.
      final staveW = edgeLengthWithGap(rMeanO, halfSpan, ring.gapMm);
      final staveWi = rMeanI <= 0 ? 0.0 : edgeLengthWithGap(rMeanI, halfSpan, ring.gapMm);
      final length = ring.thickness;
      final boardLength = physical * (length + kerfAllowanceMm);
      final segVolIn3 = (staveW / _mmPerInch) *
          (wall / _mmPerInch) *
          (length / _mmPerInch);
      return RingCutSpec(
        ring: ring,
        physicalSegments: physical,
        miterAngleDeg: 0.0,
        bevelAngleDeg: staveBevelDeg(ring.segmentCount, tilt),
        endBevelDeg: tilt * 180.0 / math.pi, // 0 for a straight tube
        outerEdgeMm: staveW,
        innerEdgeMm: staveWi,
        wallWidthMm: wall,
        thicknessMm: length,
        boardLengthMm: boardLength,
        boardFeet: physical * segVolIn3 / 144.0,
        solid: false,
        stave: true,
      );
    }

    // Flat-laid wedges: disk, normal, compound.
    final outerEdge = solid
        ? ring.outerDiameter
        : edgeLengthWithGap(rMeanO, halfSpan, ring.gapMm);
    final innerEdge = solid ? 0.0 : edgeLengthWithGap(rMeanI, halfSpan, ring.gapMm);
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
      // A compound ring adds a blade tilt equal to the wall angle.
      bevelAngleDeg: ring.type == RingType.compound ? ring.wallAngle : 0.0,
      endBevelDeg: 0.0,
      outerEdgeMm: outerEdge,
      innerEdgeMm: innerEdge,
      wallWidthMm: wall,
      thicknessMm: ring.thickness,
      boardLengthMm: boardLength,
      boardFeet: boardFeet,
      solid: solid,
      stave: false,
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
