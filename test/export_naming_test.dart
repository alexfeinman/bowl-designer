import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_bowl_designer/models/bowl_project.dart';
import 'package:segmented_bowl_designer/state/project_controller.dart';
import 'package:segmented_bowl_designer/state/project_io.dart';

void main() {
  group('filename helpers', () {
    test('sanitize replaces filename-unsafe characters', () {
      expect(ProjectIo.sanitize('Maple & Walnut Vessel'),
          'Maple _ Walnut Vessel');
      expect(ProjectIo.sanitize('  '), 'bowl'); // blank falls back
    });

    test('baseFromFilename strips extension and our suffix', () {
      expect(ProjectIo.baseFromFilename('Design.sbowl', ''), 'Design');
      expect(ProjectIo.baseFromFilename('Design-cutlist.csv', '-cutlist'),
          'Design');
      expect(ProjectIo.baseFromFilename('Design turned.png', ' turned'),
          'Design');
      // A rename that drops our suffix: keep whatever base the user typed.
      expect(ProjectIo.baseFromFilename('MyList.csv', '-cutlist'), 'MyList');
    });
  });

  group('export base name follows a save-dialog rename', () {
    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            initialProjectProvider.overrideWithValue(BowlProject.sample())
          ],
        );

    test('defaults to the sanitized design name', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(projectControllerProvider.notifier);
      expect(ctrl.suggestedExportBase(), 'Maple _ Walnut Vessel');
    });

    test('keeping the suggested name sets no override', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(projectControllerProvider.notifier);
      ctrl.noteExportFilename('', 'Maple _ Walnut Vessel.sbowl');
      expect(c.read(exportBaseNameProvider), isNull);
    });

    test('a rename is adopted for later exports without touching the design',
        () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(projectControllerProvider.notifier);
      ctrl.noteExportFilename('', 'Trial One.sbowl');
      expect(ctrl.suggestedExportBase(), 'Trial One');
      // The banner (design) name is untouched.
      expect(c.read(projectProvider).name, 'Maple & Walnut Vessel');
      // A subsequent cut-list export inherits the overridden base.
      expect(ProjectIo.baseFromFilename('Trial One-cutlist.csv', '-cutlist'),
          'Trial One');
    });

    test('editing the design name clears the override', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(projectControllerProvider.notifier);
      ctrl.noteExportFilename('', 'Trial One.sbowl');
      ctrl.rename('Second Bowl');
      expect(c.read(exportBaseNameProvider), isNull);
      expect(ctrl.suggestedExportBase(), 'Second Bowl');
      expect(c.read(projectProvider).name, 'Second Bowl');
    });

    test('loading a design clears the override', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(projectControllerProvider.notifier);
      ctrl.noteExportFilename('', 'Trial One.sbowl');
      ctrl.loadProject(BowlProject.sample());
      expect(c.read(exportBaseNameProvider), isNull);
    });
  });
}
