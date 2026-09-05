import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/ui/app.dart';

void main() {
  testWidgets('app builds and shows the title', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: BowlDesignerApp()));
    await tester.pump();
    expect(find.text('Segmented Bowl Designer'), findsOneWidget);
  });
}
