import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/bowl_project.dart';
import '../models/ring.dart';
import '../models/units.dart';
import '../ui/theme.dart';

/// Draws the bowl as a side elevation (cross-section). In [xray] mode the walls
/// become translucent and internal segment joints are drawn.
class CrossSectionPainter extends CustomPainter {
  CrossSectionPainter({
    required this.project,
    required this.xray,
    required this.colors,
    required this.unit,
    this.highlightRingId,
    this.wireframeWallMm,
  });

  final BowlProject project;
  final bool xray;
  final BowlColors colors;
  final LengthUnit unit;
  final String? highlightRingId;

  /// When set (mm), the x-ray finished wall is drawn at this uniform thickness
  /// on every course except the bottom (which stays the floor). Null = derive
  /// the wall from each ring's actual inner diameter.
  final double? wireframeWallMm;

  static const double padX = 70.0;
  static const double padTop = 40.0;
  static const double padBottom = 60.0;

  /// Which ring (id) sits under [p], or null. Uses the same layout as [paint].
  static String? ringIdAt(BowlProject project, Size size, Offset p) {
    if (project.rings.isEmpty) return null;
    final maxOd = project.maxOuterDiameterMm;
    final totalH = project.totalHeightMm;
    if (maxOd <= 0 || totalH <= 0) return null;
    final scale = math.min(
      (size.width - padX * 2) / maxOd,
      (size.height - padTop - padBottom) / totalH,
    );
    final cx = size.width / 2;
    var y = size.height - padBottom;
    for (final ring in project.rings) {
      final h = ring.thickness * scale;
      final top = y - h;
      final ro = ring.maxReachOuterDiameter / 2 * scale;
      if (p.dy >= top && p.dy <= y && (p.dx - cx).abs() <= ro) {
        return ring.id;
      }
      y = top;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (project.rings.isEmpty) return;
    final maxOd = project.maxOuterDiameterMm;
    final totalH = project.totalHeightMm;
    if (maxOd <= 0 || totalH <= 0) return;

    final scale = math.min(
      (size.width - padX * 2) / maxOd,
      (size.height - padTop - padBottom) / totalH,
    );
    final cx = size.width / 2;
    final baseY = size.height - padBottom;
    final topY = baseY - totalH * scale;

    final wallStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = colors.ink.withValues(alpha: 0.45);
    final courseLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = colors.ink.withValues(alpha: xray ? 0.25 : 0.35);

    // Captured bands for the x-ray wireframe, one per course, base first:
    // [topY, bottomY, outerR@top, outerR@bottom, innerR@top, innerR@bottom].
    // A tilted course (compound / tapered stave) flares, so top and bottom
    // radii differ; a flat ring has them equal.
    final bands = <List<double>>[];

    var y = baseY;
    for (final ring in project.rings) {
      final h = ring.thickness * scale;
      final top = y - h;
      final roB = ring.outerDiameter / 2 * scale;
      final roT = ring.topOuterDiameter / 2 * scale;
      final riB = ring.effectiveInnerDiameter / 2 * scale;
      final riT = ring.topInnerDiameter / 2 * scale;
      bands.add([top, y, roT, roB, riT, riB]);
      final baseColor = _ringColor(ring);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = xray ? baseColor.withValues(alpha: 0.10) : baseColor;

      final highlighted = ring.id == highlightRingId;

      // A trapezoid for one wall (or the full block) that leans with the flare.
      Path block(double outerB, double outerT, double innerB, double innerT) =>
          Path()
            ..moveTo(cx + innerB, y)
            ..lineTo(cx + outerB, y)
            ..lineTo(cx + outerT, top)
            ..lineTo(cx + innerT, top)
            ..close();

      if (riB <= 0.5 && riT <= 0.5) {
        final p = block(-roB, -roT, roB, roT);
        canvas.drawPath(p, fill);
        canvas.drawPath(p, wallStroke);
        if (xray) _joints(canvas, cx - roB, cx + roB, top, y, ring, colors);
      } else {
        // Left wall: outer at -ro, inner at -ri. Right wall: mirror.
        final left = block(-roB, -roT, -riB, -riT);
        final right = block(riB, riT, roB, roT);
        for (final p in [left, right]) {
          canvas.drawPath(p, fill);
          canvas.drawPath(p, wallStroke);
        }
        if (xray) {
          _joints(canvas, cx - roB, cx - riB, top, y, ring, colors);
          _joints(canvas, cx + riB, cx + roB, top, y, ring, colors);
        }
      }

      // Course glue line (along the flared top edge).
      canvas.drawLine(Offset(cx - roT, top), Offset(cx + roT, top), courseLine);

      if (highlighted) {
        final hp = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = colors.accent;
        final hr = math.max(roB, roT);
        canvas.drawRect(Rect.fromLTRB(cx - hr - 2, top - 1, cx + hr + 2, y + 1), hp);
      }
      y = top;
    }

    // X-ray: overlay a wireframe of the thickest bowl that fits the blank —
    // the outer silhouette follows each course OD, the bore follows each ID.
    if (xray) _paintProfileWireframe(canvas, cx, bands, scale);

    // Centerline.
    final center = Paint()
      ..color = colors.faint.withValues(alpha: 0.8)
      ..strokeWidth = 0.8;
    _dashedLine(canvas, Offset(cx, topY - 14), Offset(cx, baseY + 14), center);

    // Overall OD dimension.
    final maxRo = maxOd / 2 * scale;
    final dim = Paint()
      ..color = colors.muted
      ..strokeWidth = 1;
    final dy = baseY + 26;
    canvas.drawLine(Offset(cx - maxRo, dy), Offset(cx + maxRo, dy), dim);
    _tick(canvas, cx - maxRo, dy, dim);
    _tick(canvas, cx + maxRo, dy, dim);
    _label(canvas, Offset(cx, dy + 6), '⌀ ${UnitFormat.withUnit(maxOd, unit)}',
        colors.muted, center: true);

    // Height dimension on the left.
    final hx = cx - maxRo - 24;
    canvas.drawLine(Offset(hx, topY), Offset(hx, baseY), dim);
    _tick(canvas, hx, topY, dim, horizontal: false);
    _tick(canvas, hx, baseY, dim, horizontal: false);
    _label(canvas, Offset(hx - 6, (topY + baseY) / 2),
        UnitFormat.withUnit(totalH, unit), colors.muted,
        rotate: true);
  }

  Color _ringColor(Ring ring) {
    final m = ring.pattern.isNotEmpty ? ring.pattern.first : ring.materialAt(0);
    return m.color;
  }

  void _joints(Canvas c, double x0, double x1, double top, double bot, Ring ring,
      BowlColors colors) {
    final p = Paint()
      ..color = colors.accent.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    final n = math.min(ring.segmentCount, 5);
    for (var i = 1; i < n; i++) {
      final x = x0 + (x1 - x0) * i / n;
      c.drawLine(Offset(x, top), Offset(x, bot), p);
    }
  }

  /// Draw the x-ray: the finished bowl WALL (both turned surfaces) as one fair,
  /// smooth curve — but sized so no part of it crosses into empty space. The
  /// outer surface is a monotone-cubic curve through each ring's TOP-outer
  /// corner and the bore a curve through each ring's BOTTOM-inner corner — the
  /// corners where the block is most constraining for a vessel that opens
  /// upward — so the smooth curve rides just inside the blocks, touching each
  /// ring where it binds and curving in between. A light final clamp guards any
  /// residual overshoot from non-monotonic stacks. [bands] entries are
  /// [top, bottom, outerR, innerR] in screen px, base first.
  void _paintProfileWireframe(
      Canvas canvas, double cx, List<List<double>> bands, double scale) {
    if (bands.isEmpty) return;
    final topRim = bands.last[0];
    final baseBottom = bands.first[1];
    final baseTopY = bands.first[0]; // floor level: below this stays solid

    // Radius of the stock block at height [yy]. [outer] picks the outer wall
    // (indices 2=top, 3=bottom) or the bore (4=top, 5=bottom), interpolating
    // within a flared course by height.
    double blockR(double yy, bool outer) {
      final ti = outer ? 2 : 4, bi = outer ? 3 : 5;
      for (final b in bands) {
        if (yy >= b[0] - 0.5 && yy <= b[1] + 0.5) {
          final span = b[1] - b[0];
          final t = span <= 0 ? 0.0 : ((b[1] - yy) / span).clamp(0.0, 1.0);
          return b[bi] + (b[ti] - b[bi]) * t; // 0 at bottom, 1 at top
        }
      }
      if (yy < topRim) return outer ? bands.last[ti] : bands.last[ti];
      return outer ? bands.first[bi] : bands.first[bi];
    }

    // Control points at each ring's binding corner, ordered top -> bottom:
    // the outer at the ring top (widest for an opening form), the bore at the
    // ring bottom (narrowest).
    final oy = <double>[], or = <double>[]; // outer knot ys / radii
    final iy = <double>[], ir = <double>[]; // bore knot ys / radii
    for (final b in bands.reversed) {
      oy.add(b[0]);
      or.add(b[2]); // outer radius at the course top
      iy.add(b[1]);
      ir.add(b[5]); // bore radius at the course bottom
    }

    const n = 240;
    final ys = [for (var i = 0; i <= n; i++) topRim + (baseBottom - topRim) * i / n];
    final outer = _monotone(oy, or, ys);
    final inner = _monotone(iy, ir, ys);
    final wallPx = wireframeWallMm == null ? null : wireframeWallMm! * scale;
    for (var i = 0; i < ys.length; i++) {
      // Ride inside the blocks; keep the bore within the wall so it never
      // inverts and never opens a hole where the block is solid.
      outer[i] = math.min(outer[i], blockR(ys[i], true));
      if (wallPx != null && ys[i] < baseTopY - 0.5) {
        // Uniform finished wall on every course above the floor: bore the
        // inside to leave exactly this thickness, but never inside the glued
        // hole (turning removes material, it cannot add it).
        inner[i] = math.max(outer[i] - wallPx, blockR(ys[i], false));
      } else if (wallPx != null) {
        // The bottom course is the floor — keep it as glued (solid disk / hole).
        inner[i] = blockR(ys[i], false);
      } else {
        inner[i] = math.max(inner[i], blockR(ys[i], false));
      }
      inner[i] = math.min(math.max(0.0, inner[i]), outer[i]);
    }

    final outerPts = [for (var i = 0; i < ys.length; i++) Offset(outer[i], ys[i])];
    final innerPts = [for (var i = 0; i < ys.length; i++) Offset(inner[i], ys[i])];

    Path side(List<Offset> radiiY, bool right) {
      final p = Path();
      for (var i = 0; i < radiiY.length; i++) {
        final x = right ? cx + radiiY[i].dx : cx - radiiY[i].dx;
        i == 0 ? p.moveTo(x, radiiY[i].dy) : p.lineTo(x, radiiY[i].dy);
      }
      return p;
    }

    final wallFill = Paint()..color = colors.accent.withValues(alpha: 0.16);
    for (final right in const [true, false]) {
      final band = Path()..addPath(side(outerPts, right), Offset.zero);
      for (var i = innerPts.length - 1; i >= 0; i--) {
        final x = right ? cx + innerPts[i].dx : cx - innerPts[i].dx;
        band.lineTo(x, innerPts[i].dy);
      }
      band.close();
      canvas.drawPath(band, wallFill);
    }

    final outerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..color = colors.accent;
    final innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..color = colors.accent.withValues(alpha: 0.85);
    for (final right in const [true, false]) {
      canvas.drawPath(side(outerPts, right), outerStroke);
      canvas.drawPath(side(innerPts, right), innerStroke);
    }
    canvas.drawLine(Offset(cx + inner.first, topRim),
        Offset(cx + outer.first, topRim), outerStroke);
    canvas.drawLine(Offset(cx - inner.first, topRim),
        Offset(cx - outer.first, topRim), outerStroke);
  }

  /// Monotone cubic Hermite (Fritsch–Carlson) interpolation of the values [vs]
  /// sampled at ascending knots [xs], evaluated at each query in [qs]. Produces
  /// a smooth curve with no overshoot beyond the data, holding the endpoint
  /// value outside the knot range (flat rim opening / base).
  List<double> _monotone(List<double> xs, List<double> vs, List<double> qs) {
    final k = xs.length;
    if (k == 0) return [for (final _ in qs) 0.0];
    if (k == 1) return [for (final _ in qs) vs[0]];

    final d = List<double>.filled(k - 1, 0); // secant slopes
    for (var i = 0; i < k - 1; i++) {
      final dx = xs[i + 1] - xs[i];
      d[i] = dx == 0 ? 0 : (vs[i + 1] - vs[i]) / dx;
    }
    final m = List<double>.filled(k, 0); // tangents
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
      final a = m[i] / d[i];
      final b = m[i + 1] / d[i];
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

  void _dashedLine(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final s = a + dir * d;
      final e = a + dir * math.min(d + dash, total);
      c.drawLine(s, e, p);
      d += dash + gap;
    }
  }

  void _tick(Canvas c, double x, double y, Paint p, {bool horizontal = true}) {
    if (horizontal) {
      c.drawLine(Offset(x, y - 4), Offset(x, y + 4), p);
    } else {
      c.drawLine(Offset(x - 4, y), Offset(x + 4, y), p);
    }
  }

  void _label(Canvas c, Offset at, String text, Color color,
      {bool center = false, bool rotate = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppFonts.mono(TextStyle(fontSize: 11, color: color)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (rotate) {
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(-math.pi / 2);
      tp.paint(c, Offset(-tp.width / 2, -tp.height));
      c.restore();
    } else {
      tp.paint(c, Offset(at.dx - (center ? tp.width / 2 : 0), at.dy));
    }
  }

  @override
  bool shouldRepaint(covariant CrossSectionPainter old) =>
      old.project != project ||
      old.xray != xray ||
      old.highlightRingId != highlightRingId ||
      old.unit != unit ||
      old.wireframeWallMm != wireframeWallMm ||
      old.colors != colors;
}
