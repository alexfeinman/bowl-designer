import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

// ---------------------------------------------------------------------------
// Z-buffer software rasterizer.
//
// Sorting whole faces (painter's algorithm) or ordering them with a BSP tree
// both mis-resolve this mesh: many faces share planes through the axis, so no
// single draw order is correct. A per-pixel depth buffer has no ordering
// assumption — each pixel keeps the nearest fragment — so occlusion is always
// right regardless of how the faces overlap.
// ---------------------------------------------------------------------------

/// A rendered frame: the image plus a per-pixel ring-index map for hit-testing.
class RasterResult {
  RasterResult._(this.image, this.width, this.height, this._ringId);
  final ui.Image image;
  final int width;
  final int height;
  final Int32List _ringId; // 0 = empty, else ringIndex + 1

  /// Ring index under [local] (in a widget of [widgetSize]), or null.
  int? ringIndexAt(Offset local, Size widgetSize) {
    if (widgetSize.width <= 0 || widgetSize.height <= 0) return null;
    final x = (local.dx / widgetSize.width * width).floor().clamp(0, width - 1);
    final y = (local.dy / widgetSize.height * height).floor().clamp(0, height - 1);
    final r = _ringId[y * width + x];
    return r == 0 ? null : r - 1;
  }

  void dispose() => image.dispose();
}

/// Render [project] from [camera] into an image sized to [size], with the
/// segments of [highlightRingIndex] outlined in the accent colour.
Future<RasterResult?> rasterizeScene(
  BowlProject project,
  Camera3D camera,
  Size size, {
  int? highlightRingIndex,
}) {
  if (project.rings.isEmpty || size.width < 2 || size.height < 2) {
    return Future.value(null);
  }
  // Cap the internal resolution; the image is stretched to the pane on display.
  const maxDim = 900.0;
  final resScale = math.min(1.0, maxDim / math.max(size.width, size.height));
  final w = math.max(2, (size.width * resScale).round());
  final h = math.max(2, (size.height * resScale).round());

  final radius = project.maxOuterDiameterMm / 2;
  final extent = math.max(radius, project.totalHeightMm / 2) * 2.2;
  // Camera at a fixed distance (outside the object); zoom magnifies the image.
  final camDist = extent;
  final model = vm.Matrix4.identity()
    ..rotateX(camera.pitch)
    ..rotateY(camera.yaw);
  final view = vm.makeViewMatrix(
      vm.Vector3(0, 0, camDist), vm.Vector3.zero(), vm.Vector3(0, 1, 0));
  final proj = vm.makePerspectiveMatrix(45 * math.pi / 180, w / h, 1, extent * 6);
  final mvp = proj * (view * model);
  final ccx = w / 2, ccy = h / 2, zoom = camera.zoom;

  final n = w * h;
  final rgba = Uint8List(n * 4);
  final depth = Float32List(n)..fillRange(0, n, 1e30);
  final faceId = Int32List(n);
  final ringId = Int32List(n);

  final px = List<double>.filled(8, 0);
  final py = List<double>.filled(8, 0);
  final pz = List<double>.filled(8, 0);

  var fid = 0;
  for (final f in _buildFaces(project)) {
    fid++;
    final m = f.points.length;
    var ok = true;
    for (var i = 0; i < m; i++) {
      final wp = f.points[i];
      final clip = mvp.transform(vm.Vector4(wp.x, wp.y, wp.z, 1));
      if (clip.w <= 1e-6) {
        ok = false; // behind the camera
        break;
      }
      final sx = (clip.x / clip.w + 1) / 2 * w;
      final sy = (1 - (clip.y / clip.w + 1) / 2) * h;
      px[i] = ccx + (sx - ccx) * zoom;
      py[i] = ccy + (sy - ccy) * zoom;
      pz[i] = clip.w; // nearer = smaller
    }
    if (!ok) continue;

    final c = f.color;
    final r = (c.r * f.shade * 255).round().clamp(0, 255);
    final g = (c.g * f.shade * 255).round().clamp(0, 255);
    final b = (c.b * f.shade * 255).round().clamp(0, 255);
    final ring1 = f.ringIndex + 1;
    for (var k = 1; k < m - 1; k++) {
      _rasterTri(w, h, px[0], py[0], pz[0], px[k], py[k], pz[k], px[k + 1],
          py[k + 1], pz[k + 1], r, g, b, fid, ring1, rgba, depth, faceId, ringId);
    }
  }

  _edgePass(w, h, rgba, faceId, ringId,
      highlightRingIndex == null ? -1 : highlightRingIndex + 1);

  final completer = Completer<RasterResult?>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888,
      (img) => completer.complete(RasterResult._(img, w, h, ringId)));
  return completer.future;
}

void _rasterTri(
  int w,
  int h,
  double ax,
  double ay,
  double az,
  double bx,
  double by,
  double bz,
  double cx,
  double cy,
  double cz,
  int r,
  int g,
  int b,
  int fid,
  int ring1,
  Uint8List rgba,
  Float32List depth,
  Int32List faceId,
  Int32List ringId,
) {
  var minX = math.min(ax, math.min(bx, cx)).floor();
  var maxX = math.max(ax, math.max(bx, cx)).ceil();
  var minY = math.min(ay, math.min(by, cy)).floor();
  var maxY = math.max(ay, math.max(by, cy)).ceil();
  if (minX < 0) minX = 0;
  if (minY < 0) minY = 0;
  if (maxX > w - 1) maxX = w - 1;
  if (maxY > h - 1) maxY = h - 1;
  if (minX > maxX || minY > maxY) return;

  final d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
  if (d.abs() < 1e-9) return;
  final invd = 1 / d;

  for (var y = minY; y <= maxY; y++) {
    final fy = y + 0.5;
    for (var x = minX; x <= maxX; x++) {
      final fx = x + 0.5;
      final l1 = ((by - cy) * (fx - cx) + (cx - bx) * (fy - cy)) * invd;
      if (l1 < 0) continue;
      final l2 = ((cy - ay) * (fx - cx) + (ax - cx) * (fy - cy)) * invd;
      if (l2 < 0) continue;
      final l3 = 1 - l1 - l2;
      if (l3 < 0) continue;
      final zz = l1 * az + l2 * bz + l3 * cz;
      final idx = y * w + x;
      if (zz < depth[idx]) {
        depth[idx] = zz;
        final o = idx * 4;
        rgba[o] = r;
        rgba[o + 1] = g;
        rgba[o + 2] = b;
        rgba[o + 3] = 255;
        faceId[idx] = fid;
        ringId[idx] = ring1;
      }
    }
  }
}

/// Draw 1px boundaries between faces: a darker seam between segments and the
/// accent colour along the highlighted ring — recovering the crisp outlined
/// look on top of the z-buffered fills.
void _edgePass(int w, int h, Uint8List rgba, Int32List faceId, Int32List ringId,
    int hiRing) {
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final idx = y * w + x;
      final fidHere = faceId[idx];
      if (fidHere == 0) continue; // background
      var edge = false;
      var accent = false;
      if (x + 1 < w && faceId[idx + 1] != fidHere) {
        edge = true;
        if (ringId[idx] == hiRing || ringId[idx + 1] == hiRing) accent = true;
      }
      if (!edge && x > 0 && faceId[idx - 1] != fidHere) {
        edge = true;
        if (ringId[idx] == hiRing || ringId[idx - 1] == hiRing) accent = true;
      }
      if (!edge && y + 1 < h && faceId[idx + w] != fidHere) {
        edge = true;
        if (ringId[idx] == hiRing || ringId[idx + w] == hiRing) accent = true;
      }
      if (!edge && y > 0 && faceId[idx - w] != fidHere) {
        edge = true;
        if (ringId[idx] == hiRing || ringId[idx - w] == hiRing) accent = true;
      }
      if (!edge) continue;
      final o = idx * 4;
      if (accent) {
        rgba[o] = 0xD9;
        rgba[o + 1] = 0xA4;
        rgba[o + 2] = 0x41;
      } else {
        rgba[o] = (rgba[o] * 0.5).round();
        rgba[o + 1] = (rgba[o + 1] * 0.5).round();
        rgba[o + 2] = (rgba[o + 2] * 0.5).round();
      }
      rgba[o + 3] = 255;
    }
  }
}
