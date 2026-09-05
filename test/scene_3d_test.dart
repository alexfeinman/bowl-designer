import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/rendering/scene_3d.dart';

void _paint(BowlProject project, Camera3D camera) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  BowlScenePainter(
    project: project,
    camera: camera,
    edgeColor: const Color(0xFF000000),
    highlightRingIndex: 1,
  ).paint(canvas, const ui.Size(800, 600));
  rec.endRecording();
}

void main() {
  group('3D scene (BSP ordering)', () {
    test('paints the sample from several camera angles without throwing', () {
      final project = BowlProject.sample();
      for (final cam in const [
        Camera3D(),
        Camera3D(yaw: 2.1, pitch: -0.9, zoom: 1.6),
        Camera3D(yaw: -1.2, pitch: 1.3, zoom: 0.6),
      ]) {
        expect(() => _paint(project, cam), returnsNormally);
      }
    });

    test('hit-test resolves a ring under the centre or returns null', () {
      final project = BowlProject.sample();
      const cam = Camera3D();
      // Should not throw; centre of the view is over the bowl.
      final id = pickRingId(project, cam, const ui.Size(800, 600),
          const Offset(400, 300));
      expect(id == null || project.rings.any((r) => r.id == id), isTrue);
    });
  });
}
