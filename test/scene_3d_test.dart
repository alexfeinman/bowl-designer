import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/rendering/scene_3d.dart';

void main() {
  group('3D mesh geometry', () {
    test('builds one triangle buffer per ring, 3 xyz + 3 rgb per vertex', () {
      final project = BowlProject.sample();
      final rings = buildRingTriangles(project);
      expect(rings.length, project.rings.length);
      for (final rt in rings) {
        expect(rt.positions.length % 9, 0); // whole triangles (3 verts * xyz)
        expect(rt.colors.length, rt.positions.length); // rgb matches xyz count
        expect(rt.positions.isNotEmpty, isTrue);
        // colours are normalized 0..1
        for (final c in rt.colors) {
          expect(c >= 0 && c <= 1, isTrue);
        }
      }
    });

    test('exports an OBJ with vertices and faces', () {
      final obj = meshObj(BowlProject.sample());
      expect(obj.contains('\nv '), isTrue);
      expect(obj.contains('\nf '), isTrue);
    });
  });
}
