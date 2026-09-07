@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:segmented_bowl_designer/state/file_saver_io.dart';

void main() {
  const sbowl = ['sbowl', 'json'];
  const png = ['png'];

  group('suggested name handed to the save panel', () {
    test('drops our extension so macOS cannot double an unregistered one', () {
      // "Fruit bowl.sbowl" would become "Fruit bowl.sbowl.sbowl" in the panel;
      // suggesting the bare base lets the panel append it exactly once.
      expect(stripAcceptedExtension('Fruit bowl.sbowl', sbowl), 'Fruit bowl');
      expect(stripAcceptedExtension('Bowl 3d.png', png), 'Bowl 3d');
    });

    test('leaves a name with no accepted extension alone', () {
      expect(stripAcceptedExtension('Fruit bowl', sbowl), 'Fruit bowl');
    });
  });

  group('written path carries exactly one accepted extension', () {
    test('collapses a doubled extension', () {
      expect(withSingleExtension('/x/Fruit bowl.sbowl.sbowl', sbowl),
          '/x/Fruit bowl.sbowl');
    });

    test('appends the primary extension when the platform left it off', () {
      // GTK does not auto-append; ensure we still get a real extension.
      expect(withSingleExtension('/x/Fruit bowl', sbowl), '/x/Fruit bowl.sbowl');
    });

    test('keeps a single, already-correct extension', () {
      expect(withSingleExtension('/x/Fruit bowl.sbowl', sbowl),
          '/x/Fruit bowl.sbowl');
      expect(withSingleExtension('/x/list.json', sbowl), '/x/list.json');
    });
  });
}
