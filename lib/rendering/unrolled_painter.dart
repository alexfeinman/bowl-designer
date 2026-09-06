import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/bowl_project.dart';
import '../models/ring.dart';
import '../ui/theme.dart';

/// "Unrolled" (Mercator) side view: every ring is developed onto a flat,
/// equal-width horizontal band showing its *complete* ring of segments (all the
/// way around, front and back), stacked bottom → top like the elevation.
///
/// Because each band spans the full chart width regardless of the ring's real
/// circumference, the segments of smaller rings are stretched to line up with
/// the larger ones — a pattern map for planning the glue-up. Vertical extent
/// stays proportional to each ring's thickness, and the per-course rotation is
/// applied as a horizontal phase shift (wrapping at the edge) so the brick-bond
/// offset between courses reads true.
class UnrolledPainter extends CustomPainter {
  UnrolledPainter({
    required this.project,
    required this.colors,
    this.highlightRingId,
  });

  final BowlProject project;
  final BowlColors colors;
  final String? highlightRingId;

  static const double padX = 70.0;
  static const double padTop = 40.0;
  static const double padBottom = 60.0;

  static ({double scaleY, double x0, double w, double baseY})? _layout(
      BowlProject project, Size size) {
    final totalH = project.totalHeightMm;
    final w = size.width - padX * 2;
    final availH = size.height - padTop - padBottom;
    if (totalH <= 0 || w <= 0 || availH <= 0) return null;
    return (
      scaleY: availH / totalH,
      x0: padX,
      w: w,
      baseY: size.height - padBottom,
    );
  }

  /// Which ring (id) sits under [p], or null.
  static String? ringIdAt(BowlProject project, Size size, Offset p) {
    final l = _layout(project, size);
    if (l == null) return null;
    if (p.dx < l.x0 - 44 || p.dx > l.x0 + l.w + 4) return null;
    var y = l.baseY;
    for (final ring in project.rings) {
      final top = y - ring.thickness * l.scaleY;
      if (p.dy >= top && p.dy <= y) return ring.id;
      y = top;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = _layout(project, size);
    if (l == null) return;
    final x0 = l.x0, x1 = l.x0 + l.w, w = l.w;
    final rotations = project.ringRotationsRad();

    final bandBg = Paint()..color = colors.ink.withValues(alpha: 0.06);
    final courseSep = Paint()
      ..strokeWidth = 1.1
      ..color = colors.ink.withValues(alpha: 0.55);
    final jointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = colors.ink.withValues(alpha: 0.45);

    var y = l.baseY;
    for (var ringIndex = 0; ringIndex < project.rings.length; ringIndex++) {
      final ring = project.rings[ringIndex];
      final top = y - ring.thickness * l.scaleY;
      final band = Rect.fromLTRB(x0, top, x1, y);

      // The gap between segments (and the neutral background of a whole band)
      // reads as a void: paint it first, then lay the wood blocks over it.
      canvas.drawRect(band, bandBg);

      if (ring.isSolid) {
        canvas.drawRect(band, Paint()..color = ring.materialAt(0).color);
      } else {
        final n = ring.segmentCount;
        final cell = 1.0 / n; // each segment's fraction of the full turn
        // Angular gap as a fraction of the turn, split half onto each side.
        final gapFrac =
            (ring.gapAngle / (2 * math.pi)).clamp(0.0, cell * 0.9);
        final halfGap = gapFrac / 2;
        // Rotation → horizontal phase in [0,1).
        final phase = (rotations[ringIndex] / (2 * math.pi)) % 1.0;
        final isStave = ring.type == RingType.stave;

        for (var i = 0; i < n; i++) {
          final base = ((i * cell) + phase) % 1.0;
          // Wood occupies the cell minus a half-gap at each true boundary.
          final wf0 = base + halfGap;
          final wf1 = base + cell - halfGap;
          _drawWood(canvas, x0, w, top, y, wf0, wf1,
              ring.materialAt(i).color, jointPaint, isStave, colors);
        }
      }

      // Course separators so bands never bleed together.
      canvas.drawLine(Offset(x0, top), Offset(x1, top), courseSep);
      if (ringIndex == 0) {
        canvas.drawLine(Offset(x0, y), Offset(x1, y), courseSep);
      }

      // Segment-count label in the left gutter.
      final count = ring.isSolid ? 'solid' : '${ring.segmentCount}';
      _label(canvas, Offset(x0 - 10, (top + y) / 2), count,
          rightAlign: true, middle: true, faint: true);

      if (ring.id == highlightRingId) {
        canvas.drawRect(
          Rect.fromLTRB(x0 - 1, top - 1, x1 + 1, y + 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = colors.accent,
        );
      }
      y = top;
    }

    _angleScale(canvas, l);
  }

  /// Draw a wood block spanning the fraction range [wf0, wf1] of the full turn,
  /// wrapping across the right edge if it crosses fraction 1.0.
  void _drawWood(Canvas canvas, double x0, double w, double top, double bottom,
      double wf0, double wf1, Color color, Paint joint, bool isStave,
      BowlColors colors) {
    if (wf1 <= wf0) return;
    if (wf1 <= 1.0) {
      _block(canvas, x0 + wf0 * w, x0 + wf1 * w, top, bottom, color, joint,
          isStave, colors);
    } else {
      // Split at the seam; the wrap boundary itself is not a real joint, so
      // suppress the joint line on the split edges by drawing fills, then the
      // real outer joints only.
      _block(canvas, x0 + wf0 * w, x0 + w, top, bottom, color, null, isStave,
          colors);
      _block(canvas, x0, x0 + (wf1 - 1.0) * w, top, bottom, color, null,
          isStave, colors);
      // Real joints at the two true edges of this (wrapped) segment.
      canvas.drawLine(Offset(x0 + wf0 * w, top), Offset(x0 + wf0 * w, bottom),
          joint);
      canvas.drawLine(Offset(x0 + (wf1 - 1.0) * w, top),
          Offset(x0 + (wf1 - 1.0) * w, bottom), joint);
    }
  }

  void _block(Canvas canvas, double xa, double xb, double top, double bottom,
      Color color, Paint? joint, bool isStave, BowlColors colors) {
    final r = Rect.fromLTRB(xa, top, xb, bottom);
    canvas.drawRect(r, Paint()..color = color);
    // Staves read as vertical boards — hint long grain up the block.
    if (isStave) {
      final grain = Paint()
        ..strokeWidth = 0.5
        ..color = colors.ink.withValues(alpha: 0.16);
      for (final f in const [0.33, 0.66]) {
        final gx = xa + (xb - xa) * f;
        canvas.drawLine(Offset(gx, top), Offset(gx, bottom), grain);
      }
    }
    if (joint != null) {
      canvas.drawLine(Offset(xa, top), Offset(xa, bottom), joint);
      canvas.drawLine(Offset(xb, top), Offset(xb, bottom), joint);
    }
  }

  void _angleScale(Canvas canvas,
      ({double scaleY, double x0, double w, double baseY}) l) {
    final tick = Paint()
      ..color = colors.muted
      ..strokeWidth = 1;
    final yTop = l.baseY + 8;
    final yBot = l.baseY + 14;
    for (final frac in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final x = l.x0 + frac * l.w;
      canvas.drawLine(Offset(x, yTop), Offset(x, yBot), tick);
      _label(canvas, Offset(x, yBot + 3), '${(frac * 360).round()}°',
          center: true, faint: true);
    }
  }

  void _label(Canvas c, Offset at, String text,
      {bool center = false,
      bool rightAlign = false,
      bool middle = false,
      bool faint = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: AppFonts.mono(TextStyle(
              fontSize: 11, color: faint ? colors.faint : colors.muted))),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (center) dx -= tp.width / 2;
    if (rightAlign) dx -= tp.width;
    final dy = middle ? at.dy - tp.height / 2 : at.dy;
    tp.paint(c, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant UnrolledPainter old) =>
      old.project != project ||
      old.highlightRingId != highlightRingId ||
      old.colors != colors;
}
