import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/state/project_controller.dart';
import 'package:segmented_bowl_designer/ui/app.dart';

void main() {
  testWidgets('keyboard shortcuts resize the selected ring', (tester) async {
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

    // A MIDDLE ring — editing it must not snap selection back to the top.
    final id = container.read(projectProvider).rings[2].id;
    container.read(selectionControllerProvider.notifier).select(id);
    await tester.pump();

    double thickness() =>
        container.read(projectProvider).rings.firstWhere((r) => r.id == id).thickness;
    double outer() =>
        container.read(projectProvider).rings.firstWhere((r) => r.id == id).outerDiameter;

    // Thickness up via ']'.
    final t0 = thickness();
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    expect(thickness(), greaterThan(t0));

    // Outer diameter up via right arrow.
    final od0 = outer();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(outer(), greaterThan(od0));

    // Outer diameter back down via left arrow.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(outer(), closeTo(od0, 1e-6));

    // Selection must remain on the middle ring after all the edits.
    expect(container.read(selectedRingIdProvider), id);

    // Let the autosave debounce timer fire so no timers remain pending.
    await tester.pump(const Duration(milliseconds: 600));
  });
}
