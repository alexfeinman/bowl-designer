import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/models/units.dart';
import 'package:segmented_bowl_designer/state/project_controller.dart';
import 'package:segmented_bowl_designer/ui/app.dart';

void main() {
  testWidgets('unit toggle switches display unit', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [initialProjectProvider.overrideWithValue(BowlProject.sample())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BowlDesignerApp()),
    );
    await tester.pump();

    expect(container.read(displayUnitProvider), LengthUnit.mm);

    await tester.tap(find.text('inch'));
    await tester.pump();
    expect(container.read(displayUnitProvider), LengthUnit.inch);

    await tester.tap(find.text('mm'));
    await tester.pump();
    expect(container.read(displayUnitProvider), LengthUnit.mm);

    await tester.pump(const Duration(milliseconds: 600));
  });
}
