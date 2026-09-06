import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../geometry/wall_profile.dart';
import '../models/bowl_project.dart';
import '../models/ring.dart';

/// A flat, colored polygon in world space (mm), tagged with its ring index.
class _Face {
  _Face(this.points, this.color, this.shade, this.ringIndex);
  final List<vm.Vector3> points;
  final Color color;
  final double shade;
  final int ringIndex;
}

const _light = [0.35, 0.82, 0.45];

List<_Face> _buildFaces(BowlProject project) {
  final faces = <_Face>[];
  final totalH = project.totalHeightMm;
  var y = -totalH / 2;

  for (var ri = 0; ri < project.rings.length; ri++) {
    final ring = project.rings[ri];
    final y0 = y;
    final y1 = y + ring.thickness;
    final isStave = ring.type == RingType.stave;
    // Stored diameters are the base; the wall flares outward by wallRiseMm over
    // the course height (compound rings and tapered staves). Bottom = base,
    // top = base + rise. Flat rings have rise 0 and behave exactly as before.
    final rise = ring.wallRiseMm;
    final roB = ring.outerDiameter / 2;
    final roT = roB + rise;
    final riB = ring.effectiveInnerDiameter / 2;
    final riT = riB > 0 ? riB + rise : 0.0;
    final n = ring.segmentCount;
    final slot = 2 * math.pi / n;
    final half = ring.gapMm / 2; // flat gap: each face offset in by half
    // Flat wedges brick-bond with a half-segment stagger per course; staves
    // (vertical boards) stand in line, so no stagger.
    final rot = isStave ? 0.0 : ri * (math.pi / n);
    double chord(double r) => math.sqrt(math.max(0.0, r * r - half * half));
    final soB = chord(roB), soT = chord(roT);
    final siB = riB > 0 ? chord(riB) : 0.0;
    final siT = riT > 0 ? chord(riT) : 0.0;

    for (var i = 0; i < n; i++) {
      final ta = i * slot + rot;
      final tb = (i + 1) * slot + rot;
      // Unit radial (u) and inward-perpendicular (p/q) directions per face.
      final ua = Offset(math.cos(ta), math.sin(ta));
      final pa = Offset(-math.sin(ta), math.cos(ta));
      final ub = Offset(math.cos(tb), math.sin(tb));
      final qb = Offset(math.sin(tb), -math.cos(tb));
      // Segment corners: base (b) at y0, top (t) at y1, flared by the tilt.
      final oSb = ua * soB + pa * half, oSt = ua * soT + pa * half;
      final oEb = ub * soB + qb * half, oEt = ub * soT + qb * half;
      final iSb = ua * siB + pa * half, iSt = ua * siT + pa * half;
      final iEb = ub * siB + qb * half, iEt = ub * siT + qb * half;

      final col = ring.materialAt(i).color;
      vm.Vector3 v(Offset c, double yy) => vm.Vector3(c.dx, yy, c.dy);

      // Outer wall (leans out with the flare).
      _addFace(faces, [v(oSb, y0), v(oEb, y0), v(oEt, y1), v(oSt, y1)], col, ri);
      // Inner wall.
      if (riB > 0.5 || riT > 0.5) {
        _addFace(faces, [v(iSb, y0), v(iSt, y1), v(iEt, y1), v(iEb, y0)], col, ri);
      }
      // Top and bottom faces. On a stave course these are exposed end grain, so
      // darken both; on a flat ring the top is a fresh face and the bottom the
      // shadowed underside.
      _addFace(faces, [v(iSt, y1), v(oSt, y1), v(oEt, y1), v(iEt, y1)],
          isStave ? _darken(col, 0.16) : _lighten(col, 0.06), ri);
      _addFace(faces, [v(oSb, y0), v(iSb, y0), v(iEb, y0), v(oEb, y0)],
          _darken(col, isStave ? 0.22 : 0.18), ri);
      // Exposed glue faces bounding the flat gap.
      if (half > 0.001) {
        _addFace(faces, [v(iSb, y0), v(oSb, y0), v(oSt, y1), v(iSt, y1)],
            _darken(col, 0.10), ri);
        _addFace(faces, [v(oEb, y0), v(iEb, y0), v(iEt, y1), v(oEt, y1)],
            _darken(col, 0.10), ri);
      }
    }
    y = y1;
  }
  return faces;
}

void _addFace(List<_Face> faces, List<vm.Vector3> pts, Color color, int ri) {
  final normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])..normalize();
  final l = vm.Vector3(_light[0], _light[1], _light[2])..normalize();
  final shade = (0.55 + 0.45 * normal.dot(l).abs()).clamp(0.0, 1.0);
  faces.add(_Face(pts, color, shade, ri));
}

/// Triangulated geometry for one ring: interleaved xyz positions and rgb (0..1)
/// vertex colours, 3 vertices per triangle. Feeds a GPU mesh (three_js).
class RingTriangles {
  RingTriangles(this.ringIndex, this.positions, this.colors);
  final int ringIndex;
  final Float32List positions;
  final Float32List colors;
}

/// Build per-ring triangle buffers from the same geometry the 2D/OBJ paths use.
/// Colours are the raw segment material colours; GPU lighting does the shading.
List<RingTriangles> buildRingTriangles(BowlProject project) {
  final pos = <int, List<double>>{};
  final col = <int, List<double>>{};
  for (final f in _buildFaces(project)) {
    final p = pos.putIfAbsent(f.ringIndex, () => <double>[]);
    final c = col.putIfAbsent(f.ringIndex, () => <double>[]);
    final cr = f.color.r, cg = f.color.g, cb = f.color.b;
    void emit(vm.Vector3 v) {
      p..add(v.x)..add(v.y)..add(v.z);
      c..add(cr)..add(cg)..add(cb);
    }

    // Triangulate the (convex) face as a fan.
    for (var k = 1; k < f.points.length - 1; k++) {
      emit(f.points[0]);
      emit(f.points[k]);
      emit(f.points[k + 1]);
    }
  }
  final ids = pos.keys.toList()..sort();
  return [
    for (final ri in ids)
      RingTriangles(
          ri, Float32List.fromList(pos[ri]!), Float32List.fromList(col[ri]!))
  ];
}

Color _lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;
Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;

/// Triangle buffers for the *turned* bowl: the finished wall (from
/// [computeWallProfile]) revolved into a smooth surface of revolution. Grouped
/// by the ring each height belongs to, so ring highlight/picking still works.
/// Vertical facets carry the segment materials as stripes, approximating how the
/// glue-up shows on the turned surface.
List<RingTriangles> buildTurnedBowlTriangles(BowlProject project,
    {double? wallMm, int radial = 64, int samples = 120}) {
  final prof = computeWallProfile(project, wallMm: wallMm, samples: samples);
  final totalH = project.totalHeightMm;
  final y0 = -totalH / 2;
  final rings = project.rings;
  if (rings.isEmpty) return const [];

  final pos = <int, List<double>>{};
  final col = <int, List<double>>{};
  void emit(int ri, vm.Vector3 v, Color c) {
    (pos[ri] ??= <double>[])..add(v.x)..add(v.y)..add(v.z);
    (col[ri] ??= <double>[])..add(c.r)..add(c.g)..add(c.b);
  }

  vm.Vector3 pt(double r, double yMm, double ang) =>
      vm.Vector3(r * math.cos(ang), y0 + yMm, r * math.sin(ang));
  final step = 2 * math.pi / radial;

  Color matAt(int ringIdx, int j) {
    final r = rings[ringIdx.clamp(0, rings.length - 1)];
    return r.materialAt(j % r.segmentCount).color;
  }

  void quad(int ri, vm.Vector3 a, vm.Vector3 b, vm.Vector3 c, vm.Vector3 d,
      Color color) {
    emit(ri, a, color);
    emit(ri, b, color);
    emit(ri, c, color);
    emit(ri, a, color);
    emit(ri, c, color);
    emit(ri, d, color);
  }

  final n = prof.ys.length;
  const eps = 0.05;

  // Outer wall — revolve the outer profile over the whole height.
  for (var i = 0; i < n - 1; i++) {
    final ri = prof.ringAt[i];
    final ya = prof.ys[i], yb = prof.ys[i + 1];
    final ra = prof.outerR[i], rb = prof.outerR[i + 1];
    for (var j = 0; j < radial; j++) {
      final a0 = j * step, a1 = (j + 1) * step;
      final color = _darken(matAt(ri, j), 0.02);
      quad(ri, pt(ra, ya, a0), pt(rb, yb, a0), pt(rb, yb, a1), pt(ra, ya, a1),
          color);
    }
  }

  // Bore — revolve the inner profile where it is open (above the floor).
  for (var i = 0; i < n - 1; i++) {
    if (prof.innerR[i] <= eps || prof.innerR[i + 1] <= eps) continue;
    final ri = prof.ringAt[i];
    final ya = prof.ys[i], yb = prof.ys[i + 1];
    final ra = prof.innerR[i], rb = prof.innerR[i + 1];
    for (var j = 0; j < radial; j++) {
      final a0 = j * step, a1 = (j + 1) * step;
      final color = _darken(matAt(ri, j), 0.14);
      // Wound the other way so the lit face points into the bore.
      quad(ri, pt(ra, ya, a1), pt(rb, yb, a1), pt(rb, yb, a0), pt(ra, ya, a0),
          color);
    }
  }

  // Inside floor: a disk where the bore first opens.
  var floorIdx = -1;
  for (var i = 0; i < n; i++) {
    if (prof.innerR[i] > eps) {
      floorIdx = i;
      break;
    }
  }
  if (floorIdx > 0) {
    final yf = prof.ys[floorIdx];
    final rf = prof.innerR[floorIdx];
    final cFloor = _lighten(matAt(0, 0), 0.06);
    for (var j = 0; j < radial; j++) {
      final a0 = j * step, a1 = (j + 1) * step;
      emit(0, pt(0, yf, 0), cFloor);
      emit(0, pt(rf, yf, a0), cFloor);
      emit(0, pt(rf, yf, a1), cFloor);
    }
  }

  // Rim: annulus joining the outer and inner tops.
  final top = n - 1;
  final riTop = prof.ringAt[top];
  final roTop = prof.outerR[top], riBore = prof.innerR[top];
  if (riBore > eps) {
    final yTop = prof.ys[top];
    for (var j = 0; j < radial; j++) {
      final a0 = j * step, a1 = (j + 1) * step;
      final color = _lighten(matAt(riTop, j), 0.05);
      quad(riTop, pt(riBore, yTop, a0), pt(roTop, yTop, a0),
          pt(roTop, yTop, a1), pt(riBore, yTop, a1), color);
    }
  }

  // Underside disk at the base.
  final rBot = prof.outerR[0];
  final cBot = _darken(matAt(0, 0), 0.2);
  for (var j = 0; j < radial; j++) {
    final a0 = j * step, a1 = (j + 1) * step;
    emit(0, pt(0, prof.ys[0], 0), cBot);
    emit(0, pt(rBot, prof.ys[0], a1), cBot);
    emit(0, pt(rBot, prof.ys[0], a0), cBot);
  }

  final ids = pos.keys.toList()..sort();
  return [
    for (final ri in ids)
      RingTriangles(
          ri, Float32List.fromList(pos[ri]!), Float32List.fromList(col[ri]!))
  ];
}

/// Wavefront OBJ of the exact mesh the 3D view builds (same gaps, stagger,
/// per-face geometry). Vertices are not shared between faces — fine for
/// inspection in an external viewer. Lets a mesh bug be told from a render bug.
String meshObj(BowlProject project) {
  final faces = _buildFaces(project);
  final sb = StringBuffer('# Segmented Bowl Designer mesh export\n');
  var idx = 1;
  for (final f in faces) {
    for (final p in f.points) {
      sb.writeln('v ${p.x.toStringAsFixed(4)} '
          '${p.y.toStringAsFixed(4)} ${p.z.toStringAsFixed(4)}');
    }
    sb.write('f');
    for (var k = 0; k < f.points.length; k++) {
      sb.write(' ${idx + k}');
    }
    sb.writeln();
    idx += f.points.length;
  }
  return sb.toString();
}
