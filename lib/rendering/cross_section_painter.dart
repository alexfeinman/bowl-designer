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
  });

  final BowlProject project;
  final bool xray;
  final BowlColors colors;
  final LengthUnit unit;
  final String? highlightRingId;

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
      final ro = ring.outerDiameter / 2 * scale;
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

    // Captured bands (top, bottom, outerR, innerR) for the x-ray wireframe.
    final bands = <List<double>>[];

    var y = baseY;
    for (final ring in project.rings) {
      final h = ring.thickness * scale;
      final top = y - h;
      final ro = ring.outerDiameter / 2 * scale;
      final ri = ring.effectiveInnerDiameter / 2 * scale;
      bands.add([top, y, ro, ri]);
      final baseColor = _ringColor(ring);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = xray ? baseColor.withValues(alpha: 0.10) : baseColor;

      final highlighted = ring.id == highlightRingId;

      if (ri <= 0.5) {
        final r = Rect.fromLTRB(cx - ro, top, cx + ro, y);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, wallStroke);
        if (xray) _joints(canvas, cx - ro, cx + ro, top, y, ring, colors);
      } else {
        for (final side in const [-1, 1]) {
          final a = side < 0 ? cx - ro : cx + ri;
          final b = side < 0 ? cx - ri : cx + ro;
          final r = Rect.fromLTRB(a, top, b, y);
          canvas.drawRect(r, fill);
          canvas.drawRect(r, wallStroke);
          if (xray) _joints(canvas, a, b, top, y, ring, colors);
        }
      }

      // Course glue line.
      canvas.drawLine(Offset(cx - ro, top), Offset(cx + ro, top), courseLine);

      if (highlighted) {
        final hp = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = colors.accent;
        canvas.drawRect(Rect.fromLTRB(cx - ro - 2, top - 1, cx + ro + 2, y + 1), hp);
      }
      y = top;
    }

    // X-ray: overlay a wireframe of the thickest bowl that fits the blank —
    // the outer silhouette follows each course OD, the bore follows each ID.
    if (xray) _paintProfileWireframe(canvas, cx, bands);

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

  /// Draw the x-ray: the finished bowl WALL (both turned surfaces) as the
  /// *largest smooth wall that actually fits inside the segment blocks* — the
  /// outer surface is the smoothest curve that never exceeds any ring's outer
  /// radius, the bore the smoothest curve that never cuts inside any block bore.
  /// Where the rings don't stack into a fair curve the wall shows the flats /
  /// scallops it is forced into, so the turner can nudge ring diameters until
  /// the fitted wall reads smooth. [bands] entries are [top, bottom, outerR,
  /// innerR] in screen px, base first.
  void _paintProfileWireframe(Canvas canvas, double cx, List<List<double>> bands) {
    if (bands.isEmpty) return;
    final topRim = bands.last[0];
    final baseBottom = bands.first[1];

    double blockR(double y, int idx) {
      for (final b in bands) {
        if (y >= b[0] - 0.5 && y <= b[1] + 0.5) return b[idx];
      }
      return y < topRim ? bands.last[idx] : bands.first[idx];
    }

    const n = 240;
    final ys = [for (var i = 0; i <= n; i++) topRim + (baseBottom - topRim) * i / n];
    final ceil = [for (final y in ys) blockR(y, 2)]; // block outer radii
    final floor = [for (final y in ys) blockR(y, 3)]; // block bore radii

    final outer = _fitInside(ceil, ceiling: true);
    final inner = _fitInside(floor, ceiling: false);
    for (var i = 0; i < ys.length; i++) {
      // Bore stays inside the wall so the fill never inverts.
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

  /// The smoothest curve that stays inside a one-sided constraint: with
  /// [ceiling] true it never exceeds [bound] (the block outer radii); false it
  /// never drops below [bound] (the block bores). Found by relaxed Jacobi
  /// diffusion re-projected onto the constraint each pass — the curve rounds
  /// wherever it can and rests against the binding rings where it must, so a
  /// well-stacked bowl yields a fair curve and a poorly stacked one shows the
  /// scallops. Result is guaranteed on the safe side of [bound] everywhere.
  List<double> _fitInside(List<double> bound, {required bool ceiling}) {
    final v = List<double>.from(bound);
    const passes = 120;
    const relax = 0.5;
    for (var p = 0; p < passes; p++) {
      final prev = List<double>.from(v);
      for (var i = 1; i < v.length - 1; i++) {
        final avg = (prev[i - 1] + prev[i + 1]) / 2;
        v[i] = prev[i] + relax * (avg - prev[i]);
      }
      // Re-project onto the constraint so the wall always fits the blocks.
      for (var i = 0; i < v.length; i++) {
        v[i] = ceiling ? math.min(v[i], bound[i]) : math.max(v[i], bound[i]);
      }
    }
    return v;
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
      old.colors != colors;
}
