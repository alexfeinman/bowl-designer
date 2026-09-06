import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../geometry/wall_profile.dart';
import '../models/bowl_project.dart';
import '../models/ring.dart';

/// One full texture tile spans this many millimetres of wood, the same in both
/// directions (isotropic), so grain is **scaled to the real segment size**: a
/// tall segment shows proportionally more grain than a short one, and the grain
/// never stretches. Tune this one number to make the figure coarser/finer.
const double grainTileMm = 90.0;

/// Sentinel material id for a turned-bowl glue line (a gap). Its buffer is drawn
/// flat and untextured (a dark line) by the 3D view — see [_kGapColor].
const String kGapMaterialId = '__gap__';
const int _kGapColor = 0xFF241812; // dark glue-line brown

/// A flat polygon in world space (mm). For the GPU path each vertex carries a
/// grayscale [shade] multiplier (lighting/darkening cues, species-independent)
/// and a wood-grain UV; the segment's species is named by [materialId] and its
/// flat colour by [baseColor] (used when the grain overlay is off). Grouping by
/// (ringIndex, materialId) lets each species become its own textured mesh.
class _Face {
  _Face(this.points, this.ringIndex, this.materialId, this.baseColor, this.shade,
      this.uvs);
  final List<vm.Vector3> points;
  final int ringIndex;
  final String materialId;
  final int baseColor; // ARGB
  final double shade; // 0..1 grayscale multiplier
  final List<Offset> uvs;
}

/// Isotropic grain UV for a corner, given its along-grain and across-grain
/// distances in mm (grain runs along the texture's U axis).
Offset _uv(double alongMm, double acrossMm) =>
    Offset(alongMm / grainTileMm, acrossMm / grainTileMm);

List<_Face> _buildFaces(BowlProject project) {
  final faces = <_Face>[];
  final totalH = project.totalHeightMm;
  final rotations = project.ringRotationsRad();
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
    // Per-course rotation about the axis (brick-bond stagger), relative to the
    // course below; see BowlProject.ringRotationsRad.
    final rot = rotations[ri];
    double chord(double r) => math.sqrt(math.max(0.0, r * r - half * half));
    final soB = chord(roB), soT = chord(roT);
    final siB = riB > 0 ? chord(riB) : 0.0;
    final siT = riT > 0 ? chord(riT) : 0.0;

    void add(List<vm.Vector3> pts, String matId, int baseCol, double shade,
            List<Offset> uvs) =>
        faces.add(_Face(pts, ri, matId, baseCol, shade, uvs));

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

      final mat = ring.materialAt(i);
      final matId = mat.id;
      final baseCol = mat.colorValue;
      vm.Vector3 v(Offset c, double yy) => vm.Vector3(c.dx, yy, c.dy);

      // UV distances. On a flat ring the grain runs tangentially (along each
      // board's length); on a stave it runs vertically. Isotropic scale, so we
      // simply choose which axis is "along" the grain.
      final aOut = ta * roB, bOut = tb * roB; // tangential arc (outer)
      final aIn = ta * (riB > 0 ? riB : roB), bIn = tb * (riB > 0 ? riB : roB);
      Offset wallUv(double arc, double yy) =>
          isStave ? _uv(yy, arc) : _uv(arc, yy);

      // Outer wall (leans out with the flare).
      add([v(oSb, y0), v(oEb, y0), v(oEt, y1), v(oSt, y1)], matId, baseCol, 1.0,
          [wallUv(aOut, y0), wallUv(bOut, y0), wallUv(bOut, y1), wallUv(aOut, y1)]);
      // Inner wall.
      if (riB > 0.5 || riT > 0.5) {
        add([v(iSb, y0), v(iSt, y1), v(iEt, y1), v(iEb, y0)], matId, baseCol, 1.0,
            [wallUv(aIn, y0), wallUv(aIn, y1), wallUv(bIn, y1), wallUv(bIn, y0)]);
      }
      // Top and bottom faces. On a stave course these are exposed end grain, so
      // darken both; on a flat ring the top is a fresh face and the bottom the
      // shadowed underside. Grain across the ring width (radius) here.
      add([v(iSt, y1), v(oSt, y1), v(oEt, y1), v(iEt, y1)], matId, baseCol,
          isStave ? 0.84 : 1.0, [
        _uv(aIn, siT), _uv(aOut, soT), _uv(bOut, soT), _uv(bIn, siT)
      ]);
      add([v(oSb, y0), v(iSb, y0), v(iEb, y0), v(oEb, y0)], matId, baseCol,
          isStave ? 0.78 : 0.82, [
        _uv(aOut, soB), _uv(aIn, siB), _uv(bIn, siB), _uv(bOut, soB)
      ]);
      // Exposed glue faces bounding the flat gap.
      if (half > 0.001) {
        add([v(iSb, y0), v(oSb, y0), v(oSt, y1), v(iSt, y1)], matId, baseCol, 0.90,
            [_uv(siB, y0), _uv(soB, y0), _uv(soT, y1), _uv(siT, y1)]);
        add([v(oEb, y0), v(iEb, y0), v(iEt, y1), v(oEt, y1)], matId, baseCol, 0.90,
            [_uv(soB, y0), _uv(siB, y0), _uv(siT, y1), _uv(soT, y1)]);
      }
    }
    y = y1;
  }
  return faces;
}

/// Triangulated geometry for one ring + species: interleaved xyz positions,
/// rgb (0..1) shade multipliers, and grain UVs, 3 vertices per triangle. Feeds
/// a GPU mesh (three_js). [baseColor] is the species' flat colour (grain off);
/// [materialId] selects its grain texture (grain on).
class RingTriangles {
  RingTriangles(this.ringIndex, this.materialId, this.baseColor, this.positions,
      this.colors, this.uvs);
  final int ringIndex;
  final String materialId;
  final int baseColor;
  final Float32List positions;
  final Float32List colors;
  final Float32List uvs;
}

class _Bucket {
  _Bucket(this.ringIndex, this.materialId, this.baseColor);
  final int ringIndex;
  final String materialId;
  final int baseColor;
  final List<double> pos = [];
  final List<double> col = [];
  final List<double> uv = [];
}

/// Build per-(ring, species) triangle buffers from the same geometry the 2D/OBJ
/// paths use. Vertex colours are grayscale shade multipliers; the species hue
/// comes from the material (flat colour, or the grain texture).
List<RingTriangles> buildRingTriangles(BowlProject project) =>
    _bucketize(_buildFaces(project));

List<RingTriangles> _bucketize(List<_Face> faces) {
  final buckets = <String, _Bucket>{};
  for (final f in faces) {
    final key = '${f.ringIndex}|${f.materialId}';
    final b = buckets.putIfAbsent(
        key, () => _Bucket(f.ringIndex, f.materialId, f.baseColor));
    final s = f.shade;
    void emit(vm.Vector3 v, Offset uv) {
      b.pos..add(v.x)..add(v.y)..add(v.z);
      b.col..add(s)..add(s)..add(s);
      b.uv..add(uv.dx)..add(uv.dy);
    }

    // Triangulate the (convex) face as a fan.
    for (var k = 1; k < f.points.length - 1; k++) {
      emit(f.points[0], f.uvs[0]);
      emit(f.points[k], f.uvs[k]);
      emit(f.points[k + 1], f.uvs[k + 1]);
    }
  }
  final keys = buckets.keys.toList()
    ..sort((a, b) {
      final ba = buckets[a]!, bb = buckets[b]!;
      final c = ba.ringIndex.compareTo(bb.ringIndex);
      return c != 0 ? c : ba.materialId.compareTo(bb.materialId);
    });
  return [
    for (final k in keys)
      RingTriangles(
        buckets[k]!.ringIndex,
        buckets[k]!.materialId,
        buckets[k]!.baseColor,
        Float32List.fromList(buckets[k]!.pos),
        Float32List.fromList(buckets[k]!.col),
        Float32List.fromList(buckets[k]!.uv),
      )
  ];
}

/// Triangle buffers for the *turned* bowl: the finished wall (from
/// [computeWallProfile]) revolved into a smooth surface of revolution. Grouped
/// by (ring, species) — each course's real segment arcs (rotation + gaps) colour
/// the surface, so it matches the glued-rings view. Grain runs tangentially.
List<RingTriangles> buildTurnedBowlTriangles(BowlProject project,
    {double? wallMm, int samples = 120}) {
  final prof = computeWallProfile(project, wallMm: wallMm, samples: samples);
  final totalH = project.totalHeightMm;
  final y0 = -totalH / 2;
  final rings = project.rings;
  if (rings.isEmpty) return const [];
  final rotations = project.ringRotationsRad();

  final buckets = <String, _Bucket>{};
  _Bucket bucket(int ri, String matId, int baseCol) => buckets.putIfAbsent(
      '$ri|$matId', () => _Bucket(ri, matId, baseCol));

  void emit(_Bucket b, vm.Vector3 v, double shade, Offset uv) {
    b.pos..add(v.x)..add(v.y)..add(v.z);
    b.col..add(shade)..add(shade)..add(shade);
    b.uv..add(uv.dx)..add(uv.dy);
  }

  vm.Vector3 pt(double r, double yMm, double ang) =>
      vm.Vector3(r * math.cos(ang), y0 + yMm, r * math.sin(ang));

  // a,b,c,d given as (r, yMm, ang); uv computed isotropically from arc & height.
  void wallQuad(_Bucket b, double shade, double ra, double ya, double aAng,
      double rb, double yb, double bAng) {
    final a = pt(ra, ya, aAng), c = pt(rb, yb, bAng);
    final d = pt(ra, ya, bAng), e = pt(rb, yb, aAng);
    // Wound so the outward face is front (caller flips r-order for the bore).
    Offset uvAt(double r, double yMm, double ang) => _uv(ang * r, yMm);
    emit(b, a, shade, uvAt(ra, ya, aAng));
    emit(b, e, shade, uvAt(rb, yb, aAng));
    emit(b, c, shade, uvAt(rb, yb, bAng));
    emit(b, a, shade, uvAt(ra, ya, aAng));
    emit(b, c, shade, uvAt(rb, yb, bAng));
    emit(b, d, shade, uvAt(ra, ya, bAng));
  }

  // One course's arcs: (a0, a1, materialId, baseColor, shade). Gaps become a
  // darker arc of the same species (the glue line), so the surface reads the
  // segments and gaps as in the glued-rings view.
  List<(double, double, String, int, double)> arcsFor(int ringIdx) {
    final r = rings[ringIdx];
    final segN = r.segmentCount;
    final rot = rotations[ringIdx];
    if (segN <= 1) {
      final m = r.materialAt(0);
      return [(rot, rot + 2 * math.pi, m.id, m.colorValue, 1.0)];
    }
    final slot = 2 * math.pi / segN;
    final gap = r.gapAngle; // radians
    final arcs = <(double, double, String, int, double)>[];
    for (var i = 0; i < segN; i++) {
      final base = rot + i * slot;
      final m = r.materialAt(i);
      if (gap > 1e-4) {
        arcs.add((base + gap / 2, base + slot - gap / 2, m.id, m.colorValue, 1.0));
        // The gap is a glue line: its own untextured, near-black bucket so it
        // reads as a crisp line on any species instead of a faint band.
        arcs.add((base + slot - gap / 2, base + slot + gap / 2, kGapMaterialId,
            _kGapColor, 1.0));
      } else {
        arcs.add((base, base + slot, m.id, m.colorValue, 1.0));
      }
    }
    return arcs;
  }

  final ringArcs = [for (var i = 0; i < rings.length; i++) arcsFor(i)];
  const facetStep = 2 * math.pi / 96; // circumferential smoothness
  int steps(double w) => math.max(1, (w / facetStep).ceil());

  final n = prof.ys.length;
  const eps = 0.05;
  final gapBucket = bucket(-1, kGapMaterialId, _kGapColor);

  // A gap is a real slot cut through the wall: over its arc we skip the outer and
  // bore surfaces and instead draw the slot's own faces (the two radial sides,
  // plus horizontal caps at the course's top/bottom), so you can see through it.
  // A radial slot side face at a fixed angle, spanning outer↔inner over one band.
  void slotSide(int i, double ang) {
    final ya = prof.ys[i], yb = prof.ys[i + 1];
    final roa = prof.outerR[i], rob = prof.outerR[i + 1];
    final ria = prof.innerR[i], rib = prof.innerR[i + 1];
    final oA = pt(roa, ya, ang), iA = pt(ria, ya, ang);
    final iB = pt(rib, yb, ang), oB = pt(rob, yb, ang);
    emit(gapBucket, oA, 1.0, _uv(roa, ya));
    emit(gapBucket, iA, 1.0, _uv(ria, ya));
    emit(gapBucket, iB, 1.0, _uv(rib, yb));
    emit(gapBucket, oA, 1.0, _uv(roa, ya));
    emit(gapBucket, iB, 1.0, _uv(rib, yb));
    emit(gapBucket, oB, 1.0, _uv(rob, yb));
  }

  // A horizontal cap (annular sector) closing a slot's top or bottom at sample
  // [idx], across the gap's angular width.
  void slotCap(int idx, double a0, double a1) {
    final y = prof.ys[idx];
    final ro = prof.outerR[idx];
    final ri = prof.innerR[idx] > eps ? prof.innerR[idx] : 0.0;
    final st = steps(a1 - a0);
    for (var s = 0; s < st; s++) {
      final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
      emit(gapBucket, pt(ro, y, c0), 0.9, _uv(c0 * ro, ro));
      emit(gapBucket, pt(ro, y, c1), 0.9, _uv(c1 * ro, ro));
      emit(gapBucket, pt(ri, y, c1), 0.9, _uv(c1 * ri, ri));
      emit(gapBucket, pt(ro, y, c0), 0.9, _uv(c0 * ro, ro));
      emit(gapBucket, pt(ri, y, c1), 0.9, _uv(c1 * ri, ri));
      emit(gapBucket, pt(ri, y, c0), 0.9, _uv(c0 * ri, ri));
    }
  }

  bool isGap(String matId) => matId == kGapMaterialId;

  // First and last profile sample of each course (its bottom/top boundary), for
  // capping the slots.
  final ringLoIdx = <int, int>{}, ringHiIdx = <int, int>{};
  for (var i = 0; i < n; i++) {
    final r = prof.ringAt[i];
    ringLoIdx[r] = ringLoIdx.containsKey(r) ? math.min(ringLoIdx[r]!, i) : i;
    ringHiIdx[r] = ringHiIdx.containsKey(r) ? math.max(ringHiIdx[r]!, i) : i;
  }

  // Outer wall — revolve the outer profile over segment arcs; gap arcs get slot
  // side faces instead (a hole in the wall).
  for (var i = 0; i < n - 1; i++) {
    final ri = prof.ringAt[i];
    final ya = prof.ys[i], yb = prof.ys[i + 1];
    final ra = prof.outerR[i], rb = prof.outerR[i + 1];
    for (final (a0, a1, matId, baseCol, sh) in ringArcs[ri]) {
      if (isGap(matId)) {
        slotSide(i, a0);
        slotSide(i, a1);
        continue;
      }
      final b = bucket(ri, matId, baseCol);
      final st = steps(a1 - a0);
      for (var s = 0; s < st; s++) {
        final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
        wallQuad(b, sh * 0.98, ra, ya, c0, rb, yb, c1);
      }
    }
  }

  // Slot caps: close the top and bottom of each course's gaps (except where they
  // open onto the rim above or the underside below).
  for (var ri = 0; ri < rings.length; ri++) {
    if (!ringLoIdx.containsKey(ri)) continue; // course too thin to sample
    for (final (a0, a1, matId, _, _) in ringArcs[ri]) {
      if (!isGap(matId)) continue;
      if (ri > 0) slotCap(ringLoIdx[ri]!, a0, a1); // onto course below
      if (ri < rings.length - 1) slotCap(ringHiIdx[ri]!, a0, a1); // course above
    }
  }

  // Bore — revolve the inner profile where it is open (above the floor). Wound
  // the other way so the lit face points into the bore. Skips gap arcs (open).
  for (var i = 0; i < n - 1; i++) {
    if (prof.innerR[i] <= eps || prof.innerR[i + 1] <= eps) continue;
    final ri = prof.ringAt[i];
    final ya = prof.ys[i], yb = prof.ys[i + 1];
    final ra = prof.innerR[i], rb = prof.innerR[i + 1];
    for (final (a0, a1, matId, baseCol, sh) in ringArcs[ri]) {
      if (isGap(matId)) continue;
      final b = bucket(ri, matId, baseCol);
      final st = steps(a1 - a0);
      for (var s = 0; s < st; s++) {
        final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
        wallQuad(b, sh * 0.86, ra, ya, c1, rb, yb, c0);
      }
    }
  }

  // Inside floor: a pie disk (base-course arcs) where the bore first opens.
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
    for (final (a0, a1, matId, baseCol, sh) in ringArcs[0]) {
      if (isGap(matId)) continue;
      final b = bucket(0, matId, baseCol);
      final st = steps(a1 - a0);
      for (var s = 0; s < st; s++) {
        final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
        emit(b, pt(0, yf, 0), sh, _uv(0, 0));
        emit(b, pt(rf, yf, c0), sh, _uv(c0 * rf, rf));
        emit(b, pt(rf, yf, c1), sh, _uv(c1 * rf, rf));
      }
    }
  }

  // Rim: annulus joining the outer and inner tops, by the top course's arcs.
  // Gap arcs are skipped, leaving a notch in the rim.
  final top = n - 1;
  final riTop = prof.ringAt[top];
  final roTop = prof.outerR[top], riBore = prof.innerR[top];
  if (riBore > eps) {
    final yTop = prof.ys[top];
    for (final (a0, a1, matId, baseCol, sh) in ringArcs[riTop]) {
      if (isGap(matId)) continue;
      final b = bucket(riTop, matId, baseCol);
      final st = steps(a1 - a0);
      for (var s = 0; s < st; s++) {
        final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
        emit(b, pt(riBore, yTop, c0), sh, _uv(c0 * riBore, riBore));
        emit(b, pt(roTop, yTop, c0), sh, _uv(c0 * roTop, roTop));
        emit(b, pt(roTop, yTop, c1), sh, _uv(c1 * roTop, roTop));
        emit(b, pt(riBore, yTop, c0), sh, _uv(c0 * riBore, riBore));
        emit(b, pt(roTop, yTop, c1), sh, _uv(c1 * roTop, roTop));
        emit(b, pt(riBore, yTop, c1), sh, _uv(c1 * riBore, riBore));
      }
    }
  }

  // Underside disk at the base (base-course arcs, seen from below).
  final rBot = prof.outerR[0];
  for (final (a0, a1, matId, baseCol, sh) in ringArcs[0]) {
    if (isGap(matId)) continue;
    final b = bucket(0, matId, baseCol);
    final st = steps(a1 - a0);
    for (var s = 0; s < st; s++) {
      final c0 = a0 + (a1 - a0) * s / st, c1 = a0 + (a1 - a0) * (s + 1) / st;
      emit(b, pt(0, prof.ys[0], 0), sh * 0.8, _uv(0, 0));
      emit(b, pt(rBot, prof.ys[0], c1), sh * 0.8, _uv(c1 * rBot, rBot));
      emit(b, pt(rBot, prof.ys[0], c0), sh * 0.8, _uv(c0 * rBot, rBot));
    }
  }

  final keys = buckets.keys.where((k) => buckets[k]!.pos.isNotEmpty).toList()
    ..sort((a, b) {
      final ba = buckets[a]!, bb = buckets[b]!;
      final c = ba.ringIndex.compareTo(bb.ringIndex);
      return c != 0 ? c : ba.materialId.compareTo(bb.materialId);
    });
  return [
    for (final k in keys)
      RingTriangles(
        buckets[k]!.ringIndex,
        buckets[k]!.materialId,
        buckets[k]!.baseColor,
        Float32List.fromList(buckets[k]!.pos),
        Float32List.fromList(buckets[k]!.col),
        Float32List.fromList(buckets[k]!.uv),
      )
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
