import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/bowl_project.dart';

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
    final ro = ring.outerDiameter / 2;
    final rInner = ring.effectiveInnerDiameter / 2;
    final n = ring.segmentCount;
    final slot = 2 * math.pi / n;
    final half = ring.gapMm / 2; // flat gap: each face offset in by half
    final rot = ri * (math.pi / n); // half-segment stagger per course
    final so = math.sqrt(math.max(0.0, ro * ro - half * half));
    final si = rInner > 0 ? math.sqrt(math.max(0.0, rInner * rInner - half * half)) : 0.0;

    for (var i = 0; i < n; i++) {
      final ta = i * slot + rot;
      final tb = (i + 1) * slot + rot;
      // Unit radial (u) and inward-perpendicular (p/q) directions per face.
      final ua = Offset(math.cos(ta), math.sin(ta));
      final pa = Offset(-math.sin(ta), math.cos(ta));
      final ub = Offset(math.cos(tb), math.sin(tb));
      final qb = Offset(math.sin(tb), -math.cos(tb));
      // Segment corners in the ring plane (flat, parallel-offset glue faces).
      final oS = ua * so + pa * half;
      final oE = ub * so + qb * half;
      final iS = ua * si + pa * half;
      final iE = ub * si + qb * half;

      final col = ring.materialAt(i).color;
      vm.Vector3 v(Offset c, double yy) => vm.Vector3(c.dx, yy, c.dy);

      // Outer wall.
      _addFace(faces, [v(oS, y0), v(oE, y0), v(oE, y1), v(oS, y1)], col, ri);
      // Inner wall.
      if (rInner > 0.5) {
        _addFace(faces, [v(iS, y0), v(iS, y1), v(iE, y1), v(iE, y0)], col, ri);
      }
      // Top and bottom faces (bottom on every course so the underside reads
      // correctly when viewed from below).
      _addFace(faces, [v(iS, y1), v(oS, y1), v(oE, y1), v(iE, y1)],
          _lighten(col, 0.06), ri);
      _addFace(faces, [v(oS, y0), v(iS, y0), v(iE, y0), v(oE, y0)],
          _darken(col, 0.18), ri);
      // Exposed glue faces bounding the flat gap.
      if (half > 0.001) {
        _addFace(faces, [v(iS, y0), v(oS, y0), v(oS, y1), v(iS, y1)],
            _darken(col, 0.10), ri);
        _addFace(faces, [v(oE, y0), v(iE, y0), v(iE, y1), v(oE, y1)],
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
