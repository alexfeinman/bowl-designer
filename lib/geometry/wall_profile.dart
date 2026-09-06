import 'dart:math' as math;

import '../models/bowl_project.dart';

/// The finished (turned) wall of the vessel as an outer and inner (bore) radius
/// at each sampled height — the same curve the X-ray view draws. All lengths in
/// canonical millimetres; [ys] runs from 0 at the base bottom to the rim.
class WallProfile {
  WallProfile(this.ys, this.outerR, this.innerR, this.ringAt, this.baseTopY);

  /// Sample heights (mm from the base bottom), ascending.
  final List<double> ys;

  /// Outer radius at each height (mm).
  final List<double> outerR;

  /// Bore radius at each height (mm); 0 through the solid floor.
  final List<double> innerR;

  /// Index of the ring (course) each sample height belongs to.
  final List<int> ringAt;

  /// Height (mm from base bottom) of the top of the bottom course — the floor.
  final double baseTopY;
}

/// Build the finished-wall profile for [project]. When [wallMm] is set, the wall
/// is that uniform thickness on every course above the floor (the bottom course
/// stays solid/as-glued); otherwise the bore follows each ring's actual inner
/// diameter. Mirrors the smoothing and clamps used by the X-ray painter so the
/// 3D "turned" preview matches the wireframe exactly.
WallProfile computeWallProfile(BowlProject project,
    {double? wallMm, int samples = 200}) {
  final rings = project.rings;
  // Per-course band: [y0, y1, roBot, roTop, riBot, riTop] in mm, base first.
  final bands = <List<double>>[];
  var y = 0.0;
  for (final r in rings) {
    final y0 = y, y1 = y + r.thickness;
    bands.add([
      y0,
      y1,
      r.outerDiameter / 2,
      r.topOuterDiameter / 2,
      r.effectiveInnerDiameter / 2,
      r.topInnerDiameter / 2,
    ]);
    y = y1;
  }
  final totalH = y;
  if (bands.isEmpty || totalH <= 0) {
    return WallProfile([0, 1], [0, 0], [0, 0], [0, 0], 0);
  }
  final baseTopY = bands.first[1];

  // Block radius at height yy: outer (2=top,3=bottom... note bands store bottom
  // at index 2, top at 3) or bore, interpolated within a flared course.
  double blockR(double yy, bool outer) {
    final botI = outer ? 2 : 4, topI = outer ? 3 : 5;
    for (final b in bands) {
      if (yy >= b[0] - 1e-6 && yy <= b[1] + 1e-6) {
        final span = b[1] - b[0];
        final t = span <= 0 ? 0.0 : ((yy - b[0]) / span).clamp(0.0, 1.0);
        return b[botI] + (b[topI] - b[botI]) * t;
      }
    }
    return yy <= bands.first[0] ? bands.first[botI] : bands.last[topI];
  }

  int ringAt(double yy) {
    for (var i = 0; i < bands.length; i++) {
      if (yy <= bands[i][1] + 1e-6) return i;
    }
    return bands.length - 1;
  }

  // Knots (ascending y): outer at each course top (widest for an opening form),
  // bore at each course bottom (narrowest).
  final oy = <double>[], or = <double>[];
  final iy = <double>[], ir = <double>[];
  for (final b in bands) {
    oy.add(b[1]);
    or.add(b[3]);
    iy.add(b[0]);
    ir.add(b[4]);
  }

  final ys = [for (var i = 0; i <= samples; i++) totalH * i / samples];
  final outer = _monotone(oy, or, ys);
  final innerSmooth = _monotone(iy, ir, ys);
  final inner = List<double>.filled(ys.length, 0);
  final rat = <int>[];
  final wall = wallMm;
  for (var i = 0; i < ys.length; i++) {
    outer[i] = math.min(outer[i], blockR(ys[i], true));
    if (wall != null && ys[i] > baseTopY + 1e-6) {
      inner[i] = math.max(outer[i] - wall, blockR(ys[i], false));
    } else if (wall != null) {
      inner[i] = blockR(ys[i], false); // bottom course kept as glued
    } else {
      inner[i] = math.max(innerSmooth[i], blockR(ys[i], false));
    }
    inner[i] = math.min(math.max(0.0, inner[i]), outer[i]);
    rat.add(ringAt(ys[i]));
  }
  return WallProfile(ys, outer, inner, rat, baseTopY);
}

/// Monotone cubic Hermite (Fritsch–Carlson) interpolation of [vs] at ascending
/// knots [xs], evaluated at [qs]; no overshoot, holds the endpoint value beyond
/// the knot range. (Same routine the X-ray painter uses.)
List<double> _monotone(List<double> xs, List<double> vs, List<double> qs) {
  final k = xs.length;
  if (k == 0) return [for (final _ in qs) 0.0];
  if (k == 1) return [for (final _ in qs) vs[0]];

  final d = List<double>.filled(k - 1, 0);
  for (var i = 0; i < k - 1; i++) {
    final dx = xs[i + 1] - xs[i];
    d[i] = dx == 0 ? 0 : (vs[i + 1] - vs[i]) / dx;
  }
  final m = List<double>.filled(k, 0);
  m[0] = d[0];
  m[k - 1] = d[k - 2];
  for (var i = 1; i < k - 1; i++) {
    m[i] = d[i - 1] * d[i] <= 0 ? 0.0 : (d[i - 1] + d[i]) / 2;
  }
  for (var i = 0; i < k - 1; i++) {
    if (d[i] == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / d[i], b = m[i + 1] / d[i];
    final s = a * a + b * b;
    if (s > 9) {
      final t = 3 / math.sqrt(s);
      m[i] = t * a * d[i];
      m[i + 1] = t * b * d[i];
    }
  }

  return [
    for (final q in qs)
      () {
        if (q <= xs[0]) return vs[0];
        if (q >= xs[k - 1]) return vs[k - 1];
        var i = 0;
        while (i < k - 1 && q > xs[i + 1]) {
          i++;
        }
        final h = xs[i + 1] - xs[i];
        final t = (q - xs[i]) / h;
        final t2 = t * t, t3 = t2 * t;
        return (2 * t3 - 3 * t2 + 1) * vs[i] +
            (t3 - 2 * t2 + t) * h * m[i] +
            (-2 * t3 + 3 * t2) * vs[i + 1] +
            (t3 - t2) * h * m[i + 1];
      }()
  ];
}
