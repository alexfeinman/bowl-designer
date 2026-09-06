import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../export/cut_list_csv.dart';
import '../../export/cut_list_pdf.dart';
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
              Text('${specs.length} rings · ${project.totalSegments} segments',
                  style: AppFonts.ui(TextStyle(fontSize: 12, color: c.muted))),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink, side: BorderSide(color: c.borderStrong)),
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print'),
                onPressed: () => _print(ref),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink, side: BorderSide(color: c.borderStrong)),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                onPressed: () => _exportPdf(context, ref),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: c.accent, foregroundColor: c.accentInk),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('CSV'),
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
                      col('Ring'),
                      col('Type'),
                      col('Seg', numeric: true),
                      col('Miter', numeric: true),
                      col('Bevel', numeric: true),
                      col('Outer/width ($u)', numeric: true),
                      col('Inner/width ($u)', numeric: true),
                      col('Wall ($u)', numeric: true),
                      col('Len/height ($u)', numeric: true),
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
                          mono(s.solid || s.stave
                              ? '—'
                              : '${s.miterAngleDeg.toStringAsFixed(2)}°'),
                          mono(_bevelLabel(s)),
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
            'Board length includes a ${v(project.kerfAllowanceMm)} $u handling/kerf allowance per piece.  '
            'Compound rings add a blade-tilt bevel = wall angle; staves are vertical boards '
            '(rip bevel per long edge, outer/inner give the stave width, len = height).  '
            'Total ≈ ${RingGeometry.totalBoardFeet(project).toStringAsFixed(2)} board-feet.',
            style: AppFonts.ui(TextStyle(fontSize: 11.5, color: c.muted)),
          ),
        ],
      ),
    );
  }

  /// Blade-tilt bevel column: '—' when none, the angle otherwise, with a tapered
  /// stave's end back-bevel appended.
  static String _bevelLabel(RingCutSpec s) {
    if (s.bevelAngleDeg <= 0.0001) return '—';
    final main = '${s.bevelAngleDeg.toStringAsFixed(2)}°';
    if (s.endBevelDeg > 0.0001) {
      return '$main / ${s.endBevelDeg.toStringAsFixed(1)}° ends';
    }
    return main;
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

  /// Open the system print dialog (browser print on web) with the PDF cut list.
  Future<void> _print(WidgetRef ref) async {
    final project = ref.read(projectProvider);
    await Printing.layoutPdf(
      name: '${project.name} cut list',
      onLayout: (format) => buildCutListPdf(project),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final project = ref.read(projectProvider);
    try {
      final bytes = await buildCutListPdf(project);
      final ok = await ProjectIo.exportPdf(bytes, project.name);
      if (context.mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cut list PDF saved.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
      }
    }
  }
}
