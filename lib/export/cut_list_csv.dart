import 'package:csv/csv.dart';

import '../geometry/ring_geometry.dart';
import '../models/bowl_project.dart';
import '../models/units.dart';

/// Build a CSV cut list for [project] with lengths in its display [unit].
String buildCutListCsv(BowlProject project) {
  final unit = project.displayUnit;
  String v(double mm) => UnitFormat.value(mm, unit);
  final u = unit.label;

  final rows = <List<dynamic>>[
    [
      'Ring',
      'Type',
      'Segments',
      'Miter (°)',
      'Bevel (°)',
      'Outer/width ($u)',
      'Inner/width ($u)',
      'Wall ($u)',
      'Length/height ($u)',
      'Board length ($u)',
      'Board-feet',
    ],
  ];

  for (final s in RingGeometry.cutList(project)) {
    rows.add([
      s.ring.name,
      s.solid ? 'solid' : s.ring.type.name,
      s.physicalSegments,
      s.solid || s.stave ? '' : s.miterAngleDeg.toStringAsFixed(2),
      s.bevelAngleDeg > 0.0001
          ? s.bevelAngleDeg.toStringAsFixed(2) +
              (s.endBevelDeg > 0.0001
                  ? ' / ${s.endBevelDeg.toStringAsFixed(1)} ends'
                  : '')
          : '',
      v(s.outerEdgeMm),
      s.innerEdgeMm > 0 ? v(s.innerEdgeMm) : '',
      v(s.wallWidthMm),
      v(s.thicknessMm),
      v(s.boardLengthMm),
      s.boardFeet.toStringAsFixed(3),
    ]);
  }

  final totalBf = RingGeometry.totalBoardFeet(project);
  final totalSeg = project.rings.fold(0, (a, r) => a + r.physicalSegmentCount);
  rows.add([
    'TOTAL',
    '',
    totalSeg,
    '',
    '',
    '',
    '',
    '',
    v(project.totalHeightMm),
    '',
    totalBf.toStringAsFixed(3),
  ]);

  return const ListToCsvConverter().convert(rows);
}
