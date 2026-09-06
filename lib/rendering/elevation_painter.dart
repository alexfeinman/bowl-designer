import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/bowl_project.dart';
import '../models/ring.dart';
import '../models/units.dart';
import '../ui/theme.dart';

/// Side elevation: the bowl seen from the side (an orthographic front
/// projection), so the front-facing segments of each ring are visible with
/// realistic foreshortening toward the edges — not a cross-section.
class ElevationPainter extends CustomPainter {
  ElevationPainter({
    required this.project,
    required this.colors,
    required this.unit,
    this.highlightRingId,
  });

  final BowlProject project;
  final BowlColors colors;
  final LengthUnit unit;
  final String? highlightRingId;

  static const double padX = 70.0;
  static const double padTop = 40.0;
  static const double padBottom = 60.0;

  static ({double scale, double cx, double baseY})? _layout(
      BowlProject project, Size size) {
    final maxOd = project.maxOuterDiameterMm;
    final totalH = project.totalHeightMm;
    if (maxOd <= 0 || totalH <= 0) return null;
    final scale = math.min(
      (size.width - padX * 2) / maxOd,
      (size.height - padTop - padBottom) / totalH,
    );
    return (scale: scale, cx: size.width / 2, baseY: size.height - padBottom);
  }

  /// Which ring (id) sits under [p], or null.
  static String? ringIdAt(BowlProject project, Size size, Offset p) {
    final l = _layout(project, size);
    if (l == null) return null;
    var y = l.baseY;
    for (final ring in project.rings) {
      final top = y - ring.thickness * l.scale;
      final ro = ring.maxReachOuterDiameter / 2 * l.scale;
      if (p.dy >= top && p.dy <= y && (p.dx - l.cx).abs() <= ro) return ring.id;
      y = top;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = _layout(project, size);
    if (l == null) return;
    final scale = l.scale, cx = l.cx;
    final rotations = project.ringRotationsRad();

    var y = l.baseY;
    for (var ringIndex = 0; ringIndex < project.rings.length; ringIndex++) {
      final ring = project.rings[ringIndex];
      final isStave = ring.type == RingType.stave;
      final h = ring.thickness * scale;
      final top = y - h;
      // Base (bottom) and flared (top) outer radii — equal for a flat ring.
      final roB = ring.outerDiameter / 2 * scale;
      final roT = ring.topOuterDiameter / 2 * scale;
      final n = ring.segmentCount;
      final slot = 2 * math.pi / n;
      final half = ring.gapMm / 2 * scale; // flat gap half-width in px
      // Per-course rotation about the axis (see BowlProject.ringRotationsRad).
      final rot = rotations[ringIndex];
      double chord(double r) => math.sqrt(math.max(0.0, r * r - half * half));
      final soB = chord(roB), soT = chord(roT);

      if (ring.isSolid) {
        canvas.drawRect(Rect.fromLTRB(cx - roB, top, cx + roB, y),
            Paint()..color = ring.materialAt(0).color);
      } else {
        final jointPaint = Paint()
          ..strokeWidth = 0.7
          ..color = colors.ink.withValues(alpha: 0.45);
        for (var i = 0; i < n; i++) {
          final ta = i * slot + rot;
          final tb = (i + 1) * slot + rot;
          final mid = (ta + tb) / 2;
          if (math.sin(mid) <= 0.02) continue; // back-facing (behind the bowl)
          // Outer-face corners at the base and the flared top, projected.
          final xSb = cx + soB * math.cos(ta) - half * math.sin(ta);
          final xEb = cx + soB * math.cos(tb) + half * math.sin(tb);
          final xSt = cx + soT * math.cos(ta) - half * math.sin(ta);
          final xEt = cx + soT * math.cos(tb) + half * math.sin(tb);
          final shade = 0.68 + 0.32 * math.sin(mid);
          final base = ring.materialAt(i).color;
          final facet = Path()
            ..moveTo(xSb, y)
            ..lineTo(xEb, y)
            ..lineTo(xEt, top)
            ..lineTo(xSt, top)
            ..close();
          canvas.drawPath(
            facet,
            Paint()
              ..color = Color.from(
                  alpha: 1, red: base.r * shade, green: base.g * shade, blue: base.b * shade),
          );
          // Segment joints — the leaning edges of the facet.
          canvas.drawLine(Offset(xSb, y), Offset(xSt, top), jointPaint);
          canvas.drawLine(Offset(xEb, y), Offset(xEt, top), jointPaint);
          // Grain cue: staves read as vertical boards, so hint long grain up
          // the facet; flat wedges show end grain (no hint).
          if (isStave) {
            final grain = Paint()
              ..strokeWidth = 0.5
              ..color = colors.ink.withValues(alpha: 0.16);
            for (final f in const [0.33, 0.66]) {
              canvas.drawLine(
                Offset(xSb + (xEb - xSb) * f, y),
                Offset(xSt + (xEt - xSt) * f, top),
                grain,
              );
            }
          }
        }
      }

      // Course separators so adjacent rings never bleed into one another:
      // a firm line along this ring's (flared) top edge, plus the base's bottom
      // edge for the very first ring.
      final courseSep = Paint()
        ..strokeWidth = 1.1
        ..color = colors.ink.withValues(alpha: 0.55);
      canvas.drawLine(Offset(cx - roT, top), Offset(cx + roT, top), courseSep);
      if (ringIndex == 0) {
        canvas.drawLine(Offset(cx - roB, y), Offset(cx + roB, y), courseSep);
      }

      if (ring.id == highlightRingId) {
        final hr = math.max(roB, roT);
        canvas.drawRect(
          Rect.fromLTRB(cx - hr - 2, top - 1, cx + hr + 2, y + 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = colors.accent,
        );
      }
      y = top;
    }

    _dimensions(canvas, size, l);
  }

  void _dimensions(Canvas canvas, Size size,
      ({double scale, double cx, double baseY}) l) {
    final maxOd = project.maxOuterDiameterMm;
    final totalH = project.totalHeightMm;
    final topY = l.baseY - totalH * l.scale;
    final maxRo = maxOd / 2 * l.scale;
    final dim = Paint()
      ..color = colors.muted
      ..strokeWidth = 1;
    final dy = l.baseY + 26;
    canvas.drawLine(Offset(l.cx - maxRo, dy), Offset(l.cx + maxRo, dy), dim);
    _label(canvas, Offset(l.cx, dy + 6), '⌀ ${UnitFormat.withUnit(maxOd, unit)}',
        center: true);
    final hx = l.cx - maxRo - 24;
    canvas.drawLine(Offset(hx, topY), Offset(hx, l.baseY), dim);
    _label(canvas, Offset(hx - 6, (topY + l.baseY) / 2),
        UnitFormat.withUnit(totalH, unit),
        rotate: true);
  }

  void _label(Canvas c, Offset at, String text,
      {bool center = false, bool rotate = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: AppFonts.mono(TextStyle(fontSize: 11, color: colors.muted))),
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
  bool shouldRepaint(covariant ElevationPainter old) =>
      old.project != project ||
      old.highlightRingId != highlightRingId ||
      old.unit != unit ||
      old.colors != colors;
}
