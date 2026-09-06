import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/models/ring.dart';
import 'package:segmented_bowl_designer/rendering/scene_3d.dart';

void main() {
  group('3D mesh geometry', () {
    test('buffers are whole triangles with matching colour + uv counts', () {
      final project = BowlProject.sample();
      final tris = buildRingTriangles(project);
      expect(tris.isNotEmpty, isTrue);
      for (final rt in tris) {
        expect(rt.positions.length % 9, 0); // whole triangles (3 verts * xyz)
        expect(rt.colors.length, rt.positions.length); // rgb matches xyz count
        // uv: 2 per vertex, and 3 verts per xyz-triple.
        expect(rt.uvs.length, rt.positions.length ~/ 3 * 2);
        expect(rt.positions.isNotEmpty, isTrue);
        expect(rt.materialId.isNotEmpty, isTrue);
        for (final c in rt.colors) {
          expect(c >= 0 && c <= 1, isTrue); // normalized shade multipliers
        }
        for (final v in rt.positions) {
          expect(v.isFinite, isTrue);
        }
      }
    });

    test('every ring is represented by at least one buffer', () {
      final project = BowlProject.sample();
      final tris = buildRingTriangles(project);
      final ringIdx = tris.map((t) => t.ringIndex).toSet();
      for (var i = 0; i < project.rings.length; i++) {
        expect(ringIdx.contains(i), isTrue);
      }
    });

    test('a two-species ring splits into a buffer per material', () {
      final project = BowlProject.sample();
      // Ring 1 (index 1) uses a two-wood pattern → two material buffers.
      final forRing1 = buildRingTriangles(project)
          .where((t) => t.ringIndex == 1)
          .map((t) => t.materialId)
          .toSet();
      expect(forRing1.length, greaterThanOrEqualTo(2));
    });

    test('exports an OBJ with vertices and faces', () {
      final obj = meshObj(BowlProject.sample());
      expect(obj.contains('\nv '), isTrue);
      expect(obj.contains('\nf '), isTrue);
    });
  });

  group('turned bowl geometry', () {
    // A project with gaps and a non-default rotation, to exercise the arc code.
    BowlProject gapped() {
      final p = BowlProject.sample();
      return p.copyWith(rings: [
        for (var i = 0; i < p.rings.length; i++)
          p.rings[i].copyWith(
            gapMm: p.rings[i].type == RingType.disk ? 0.0 : 3.0,
            rotationDeg: i == 2 ? 5.0 : null,
          ),
      ]);
    }

    test('produces finite, in-range, whole-triangle buffers with uvs', () {
      final tris = buildTurnedBowlTriangles(gapped());
      expect(tris.isNotEmpty, isTrue);
      for (final rt in tris) {
        expect(rt.positions.length % 9, 0);
        expect(rt.colors.length, rt.positions.length);
        expect(rt.uvs.length, rt.positions.length ~/ 3 * 2);
        expect(rt.positions.isNotEmpty, isTrue);
        for (final v in rt.positions) {
          expect(v.isFinite, isTrue);
        }
        for (final v in rt.uvs) {
          expect(v.isFinite, isTrue);
        }
        for (final c in rt.colors) {
          expect(c >= 0 && c <= 1, isTrue);
        }
      }
    });

    test('a uniform wall bores the surface further in than the glued bore', () {
      final withWall = buildTurnedBowlTriangles(gapped(), wallMm: 6);
      final auto = buildTurnedBowlTriangles(gapped());
      // Min radius reached (bore) should be smaller with a thin forced wall.
      double minR(List<RingTriangles> ts) {
        var m = double.infinity;
        for (final rt in ts) {
          for (var i = 0; i < rt.positions.length; i += 3) {
            final x = rt.positions[i], z = rt.positions[i + 2];
            final r = x * x + z * z;
            if (r < m) m = r;
          }
        }
        return m;
      }

      expect(minR(withWall), lessThanOrEqualTo(minR(auto) + 1e-6));
    });
  });
}
