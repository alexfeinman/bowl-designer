import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/models/ring.dart';
import 'package:segmented_bowl_designer/models/units.dart';
import 'package:segmented_bowl_designer/rendering/cross_section_painter.dart';
import 'package:segmented_bowl_designer/ui/theme.dart';

/// Pump the X-ray painter inside a real widget tree (so google_fonts' async
/// fallback is handled by the framework, as in the app) and assert that its
/// paint pass raised no exception — a synchronous throw inside paint surfaces
/// via [WidgetTester.takeException].
Future<void> _pumpXray(WidgetTester tester, BowlProject project) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CustomPaint(
        painter: CrossSectionPainter(
          project: project,
          xray: true,
          colors: BowlColors.light,
          unit: LengthUnit.mm,
        ),
        size: const Size(800, 600),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('X-ray finished-wall profile', () {
    testWidgets('paints without throwing when a bore is wider than a lower '
        'ring OD', (tester) async {
      // A narrow base disk (OD 130) under a ring whose bore (ID 138 -> r 69)
      // exceeds the disk radius (65). This used to make the profile clamp with
      // lower > upper and throw num.clamp's ArgumentError, aborting the whole
      // wireframe. It must now render clean.
      final project = BowlProject(
        name: 'regression',
        rings: [
          Ring(
            id: 'base',
            name: 'Base disk',
            type: RingType.disk,
            outerDiameter: 130,
            innerDiameter: 0,
            thickness: 12,
            segmentCount: 12,
          ),
          Ring(
            id: 'r1',
            name: 'Ring 1',
            type: RingType.normal,
            outerDiameter: 240,
            innerDiameter: 138,
            thickness: 20,
            segmentCount: 16,
          ),
        ],
      );
      await _pumpXray(tester, project);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints the seeded sample without throwing', (tester) async {
      await _pumpXray(tester, BowlProject.sample());
      expect(tester.takeException(), isNull);
    });
  });
}
