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
/// [edgeVis] marks, per edge i (points[i] -> points[i+1]), whether it is an
/// original segment boundary (true) or a seam introduced by BSP splitting
/// (false); null means every edge is original.
class _Face {
  _Face(this.points, this.color, this.shade, this.ringIndex, [this.edgeVis]);
  final List<vm.Vector3> points;
  final Color color;
  final double shade;
  final int ringIndex;
  final List<bool>? edgeVis;

  bool edgeVisible(int i) => edgeVis == null || edgeVis![i];
}

/// A projected, shaded face ready to draw or hit-test.
class _Projected {
  _Projected(this.pts, this.depth, this.color, this.ringIndex, this.edgeVis);
  final List<Offset> pts;
  final double depth; // view-space z; larger (less negative) = nearer camera
  final Color color;
  final int ringIndex;
  final List<bool>? edgeVis;

  bool edgeVisible(int i) => edgeVis == null || edgeVis![i];
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

// ---------------------------------------------------------------------------
// BSP tree — exact hidden-surface ordering.
//
// Depth-sorting whole faces (painter's algorithm) can't resolve faces that
// overlap in screen space at different depths, so a low ring's top face could
// paint over the walls in front of it. A BSP tree splits any face that
// straddles another's plane and, for a given eye, yields a provably correct
// back-to-front draw order. It's built once per geometry (cached) and only the
// traversal depends on the camera.
// ---------------------------------------------------------------------------

const double _bspEps = 1e-4;

class _Plane {
  _Plane(this.n, this.d);
  final vm.Vector3 n;
  final double d;
  double side(vm.Vector3 p) => n.dot(p) - d;
}

_Plane _planeOf(List<vm.Vector3> pts) {
  final n = (pts[1] - pts[0]).cross(pts[2] - pts[0])..normalize();
  return _Plane(n, n.dot(pts[0]));
}

class _BspNode {
  _BspNode(this.plane);
  final _Plane plane;
  final List<_Face> coplanar = [];
  _BspNode? front;
  _BspNode? back;
}

/// Clip [face] to one half-space of [plane], keeping the front (side >= 0) when
/// [keepFront], else the back. Carries edge-visibility through so the seam left
/// along the cut plane is marked invisible while original boundaries are kept.
_Face? _clip(_Face face, _Plane plane, List<double> sides, bool keepFront) {
  final pts = <vm.Vector3>[];
  final vis = <bool>[];
  final s = keepFront ? 1.0 : -1.0; // orient tests so "inside" is side*s >= 0
  final n = face.points.length;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final a = face.points[i], b = face.points[j];
    final sa = sides[i] * s, sb = sides[j] * s;
    final e = face.edgeVisible(i);
    final aIn = sa >= -_bspEps;
    final bIn = sb >= -_bspEps;
    if (aIn) {
      pts.add(a);
      if (bIn) {
        vis.add(e); // whole edge kept, still original
      } else {
        vis.add(e); // a -> intersection: original portion
        final t = sides[i] / (sides[i] - sides[j]);
        pts.add(a + (b - a) * t);
        vis.add(false); // intersection -> next: the cut seam
      }
    } else if (bIn) {
      final t = sides[i] / (sides[i] - sides[j]);
      pts.add(a + (b - a) * t);
      vis.add(e); // intersection -> b: original portion
    }
  }
  if (pts.length < 3) return null;
  return _Face(pts, face.color, face.shade, face.ringIndex, vis);
}

/// Classify [f] against [plane], adding it (whole or split) to the right bucket.
void _classify(_Face f, _Plane plane, List<_Face> coplanar, List<_Face> front,
    List<_Face> back) {
  final sides = [for (final p in f.points) plane.side(p)];
  var hasF = false, hasB = false;
  for (final s in sides) {
    if (s > _bspEps) hasF = true;
    if (s < -_bspEps) hasB = true;
  }
  if (!hasF && !hasB) {
    coplanar.add(f); // lies in the plane
    return;
  }
  if (!hasB) {
    front.add(f);
    return;
  }
  if (!hasF) {
    back.add(f);
    return;
  }
  final fp = _clip(f, plane, sides, true);
  final bp = _clip(f, plane, sides, false);
  if (fp != null) front.add(fp);
  if (bp != null) back.add(bp);
}

_BspNode? _buildBsp(List<_Face> faces) {
  if (faces.isEmpty) return null;
  final node = _BspNode(_planeOf(faces[0].points));
  node.coplanar.add(faces[0]);
  final front = <_Face>[];
  final back = <_Face>[];
  for (var i = 1; i < faces.length; i++) {
    _classify(faces[i], node.plane, node.coplanar, front, back);
  }
  node.front = _buildBsp(front);
  node.back = _buildBsp(back);
  return node;
}

/// Append faces to [out] in back-to-front order as seen from [eye].
void _bspOrder(_BspNode? node, vm.Vector3 eye, List<_Face> out) {
  if (node == null) return;
  if (node.plane.side(eye) >= 0) {
    _bspOrder(node.back, eye, out); // far half first
    out.addAll(node.coplanar);
    _bspOrder(node.front, eye, out);
  } else {
    _bspOrder(node.front, eye, out);
    out.addAll(node.coplanar);
    _bspOrder(node.back, eye, out);
  }
}

// Cache the tree by project identity (immutable; edits produce a new instance).
BowlProject? _cachedProject;
_BspNode? _cachedTree;

List<_Face> _orderedFaces(BowlProject project, vm.Matrix4 viewModel) {
  if (!identical(project, _cachedProject)) {
    _cachedTree = _buildBsp(_buildFaces(project));
    _cachedProject = project;
  }
  // Eye position in geometry space = inverse(viewModel) applied to the origin.
  final eye = (viewModel.clone()..invert()).transform3(vm.Vector3.zero());
  final out = <_Face>[];
  _bspOrder(_cachedTree, eye, out);
  return out;
}

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

  // Faces already come back in exact back-to-front order from the BSP tree, so
  // no depth sorting (and no per-face heuristic) is needed — just project them.
  final out = <_Projected>[];
  for (final f in _orderedFaces(project, viewModel)) {
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
    out.add(_Projected(
        screen, depthSum / f.points.length, color, f.ringIndex, f.edgeVis));
  }
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
      // Stroke only original segment boundaries, not BSP split seams.
      final edge = d.ringIndex == highlightRingIndex ? hi : stroke;
      for (var i = 0; i < d.pts.length; i++) {
        if (!d.edgeVisible(i)) continue;
        canvas.drawLine(d.pts[i], d.pts[(i + 1) % d.pts.length], edge);
      }
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
