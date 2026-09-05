import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../export/cut_list_csv.dart';
import '../../geometry/ring_geometry.dart';
import '../../models/units.dart';
import '../../state/project_controller.dart';
import '../../state/project_io.dart';
import '../theme.dart';

class CutListView extends ConsumerWidget {
  const CutListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider);
    final unit = ref.watch(displayUnitProvider);
    final specs = RingGeometry.cutList(project);
    final u = unit.label;

    String v(double mm) => UnitFormat.value(mm, unit);

    final headStyle = AppFonts.ui(TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: c.faint,
    ));
    final cellMono = AppFonts.mono(TextStyle(fontSize: 12, color: c.ink));

    DataColumn col(String label, {bool numeric = false}) =>
        DataColumn(numeric: numeric, label: Text(label.toUpperCase(), style: headStyle));

    DataCell mono(String s) => DataCell(Text(s, style: cellMono));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Cut list',
                  style: AppFonts.display(TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, color: c.ink))),
              const SizedBox(width: 10),
              Text('${specs.length} courses · ${project.totalSegments} segments',
                  style: AppFonts.ui(TextStyle(fontSize: 12, color: c.muted))),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: c.accent, foregroundColor: c.accentInk),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                onPressed: () => _export(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(c.panel),
                    columns: [
                      col('Course'),
                      col('Type'),
                      col('Seg', numeric: true),
                      col('Miter', numeric: true),
                      col('Outer edge ($u)', numeric: true),
                      col('Inner edge ($u)', numeric: true),
                      col('Wall ($u)', numeric: true),
                      col('Height ($u)', numeric: true),
                      col('Board len ($u)', numeric: true),
                      col('Bd-ft', numeric: true),
                    ],
                    rows: [
                      for (final s in specs)
                        DataRow(cells: [
                          DataCell(Text(s.ring.name,
                              style: AppFonts.ui(
                                  TextStyle(fontSize: 12, color: c.ink)))),
                          DataCell(Text(s.solid ? 'solid' : s.ring.type.name,
                              style: AppFonts.mono(
                                  TextStyle(fontSize: 10.5, color: c.faint)))),
                          mono('${s.physicalSegments}'),
                          mono(s.solid ? '—' : '${s.miterAngleDeg.toStringAsFixed(2)}°'),
                          mono(v(s.outerEdgeMm)),
                          mono(s.innerEdgeMm > 0 ? v(s.innerEdgeMm) : '—'),
                          mono(v(s.wallWidthMm)),
                          mono(v(s.thicknessMm)),
                          mono(v(s.boardLengthMm)),
                          mono(s.boardFeet.toStringAsFixed(2)),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Board length includes a ${v(project.kerfAllowanceMm)} $u handling/kerf allowance per segment.  '
            'Total ≈ ${RingGeometry.totalBoardFeet(project).toStringAsFixed(2)} board-feet.',
            style: AppFonts.ui(TextStyle(fontSize: 11.5, color: c.muted)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final project = ref.read(projectProvider);
    final csv = buildCutListCsv(project);
    final ok = await ProjectIo.exportCsv(csv, project.name);
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cut list exported.')),
      );
    }
  }
}
