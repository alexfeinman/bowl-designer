import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/bowl_project.dart';

/// Orbit camera state for the 3D view.
class Camera3D {
  const Camera3D({this.yaw = 0.6, this.pitch = 0.5, this.zoom = 1.0});

  final double yaw;
  final double pitch;
  final double zoom;

  Camera3D rotated(double dYaw, double dPitch) => Camera3D(
        yaw: yaw + dYaw,
        pitch: (pitch + dPitch).clamp(-1.4, 1.4),
        zoom: zoom,
      );

  Camera3D zoomed(double factor) =>
      Camera3D(yaw: yaw, pitch: pitch, zoom: (zoom * factor).clamp(0.4, 6.0));
}

/// A flat, colored polygon in world space (mm), tagged with its ring index.
class _Face {
  _Face(this.points, this.color, this.shade, this.ringIndex);
  final List<vm.Vector3> points;
  final Color color;
  final double shade;
  final int ringIndex;
}

/// A projected, shaded face ready to draw or hit-test.
class _Projected {
  _Projected(this.pts, this.depth, this.color, this.ringIndex);
  final List<Offset> pts;
  final double depth; // view-space z; larger (less negative) = nearer camera
  final Color color;
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
    final rot = ri * (math.pi / n); // #4 half-segment stagger per course
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
      // Top and bottom faces (bottom now on every course, so the underside
      // reads correctly when viewed from below).
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

Color _lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;
Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;

/// Project every face to screen space and shade it, nearest last (draw order).
List<_Projected> _projectScene(
    BowlProject project, Camera3D camera, Size size, bool xray) {
  final radius = project.maxOuterDiameterMm / 2;
  final extent = math.max(radius, project.totalHeightMm / 2) * 2.2;
  final camDist = extent / camera.zoom;

  final model = vm.Matrix4.identity()
    ..rotateX(camera.pitch)
    ..rotateY(camera.yaw);
  final view = vm.makeViewMatrix(
      vm.Vector3(0, 0, camDist), vm.Vector3.zero(), vm.Vector3(0, 1, 0));
  final aspect = size.width <= 0 || size.height <= 0 ? 1.0 : size.width / size.height;
  final proj = vm.makePerspectiveMatrix(45 * math.pi / 180, aspect, 1, extent * 6);
  final viewModel = view * model;
  final mvp = proj * viewModel;

  final out = <_Projected>[];
  for (final f in _buildFaces(project)) {
    final screen = <Offset>[];
    var depthSum = 0.0;
    var ok = true;
    for (final wp in f.points) {
      final v = viewModel.transformed3(wp);
      depthSum += v.z;
      final clip = mvp.transform(vm.Vector4(wp.x, wp.y, wp.z, 1));
      if (clip.w.abs() < 1e-6) {
        ok = false;
        break;
      }
      screen.add(Offset(
        (clip.x / clip.w + 1) / 2 * size.width,
        (1 - (clip.y / clip.w + 1) / 2) * size.height,
      ));
    }
    if (!ok) continue;
    final base = f.color;
    final color = Color.from(
      alpha: xray ? 0.34 : 1.0,
      red: base.r * f.shade,
      green: base.g * f.shade,
      blue: base.b * f.shade,
    );
    out.add(_Projected(screen, depthSum / f.points.length, color, f.ringIndex));
  }

  // The rings are stacked along Y, so inter-course occlusion is decided by the
  // stacking order as seen from the camera: whichever end of the stack is
  // nearer must be painted last. Within a course, plain depth sorting works.
  final topZ = viewModel.transformed3(vm.Vector3(0, project.totalHeightMm / 2, 0)).z;
  final botZ = viewModel.transformed3(vm.Vector3(0, -project.totalHeightMm / 2, 0)).z;
  final topNearer = topZ > botZ; // larger view-z = nearer the camera
  out.sort((a, b) {
    if (a.ringIndex != b.ringIndex) {
      return topNearer
          ? a.ringIndex.compareTo(b.ringIndex) // draw base first, rim last
          : b.ringIndex.compareTo(a.ringIndex);
    }
    return a.depth.compareTo(b.depth); // within a course: farthest first
  });
  return out;
}

bool _polyContains(List<Offset> poly, Offset p) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if (((a.dy > p.dy) != (b.dy > p.dy)) &&
        (p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
      inside = !inside;
    }
  }
  return inside;
}

/// The ring id under [offset] in the 3D view, or null.
String? pickRingId(BowlProject project, Camera3D camera, Size size, Offset offset) {
  if (project.rings.isEmpty) return null;
  final projected = _projectScene(project, camera, size, false);
  // Nearest faces are last in draw order; test them first.
  for (final f in projected.reversed) {
    if (_polyContains(f.pts, offset)) {
      return project.rings[f.ringIndex].id;
    }
  }
  return null;
}

/// Renders the bowl mesh with perspective, depth sorting, and shading.
class BowlScenePainter extends CustomPainter {
  BowlScenePainter({
    required this.project,
    required this.camera,
    required this.edgeColor,
    this.highlightRingIndex,
  });

  final BowlProject project;
  final Camera3D camera;
  final Color edgeColor;
  final int? highlightRingIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (project.rings.isEmpty) return;
    final drawable = _projectScene(project, camera, size, false);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = edgeColor.withValues(alpha: 0.28);
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFD9A441);

    for (final d in drawable) {
      final path = Path()..addPolygon(d.pts, true);
      fill.color = d.color;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, d.ringIndex == highlightRingIndex ? hi : stroke);
    }
  }

  @override
  bool shouldRepaint(covariant BowlScenePainter old) =>
      old.project != project ||
      old.camera.yaw != camera.yaw ||
      old.camera.pitch != camera.pitch ||
      old.camera.zoom != camera.zoom ||
      old.highlightRingIndex != highlightRingIndex;
}
