import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../geometry/ring_geometry.dart';
import '../models/bowl_project.dart';
import '../models/units.dart';

/// Build a printable PDF cut list for [project], lengths in its display unit.
Future<Uint8List> buildCutListPdf(BowlProject project) async {
  final unit = project.displayUnit;
  final u = unit.label;
  String v(double mm) => UnitFormat.value(mm, unit);

  final specs = RingGeometry.cutList(project);
  final totalBf = RingGeometry.totalBoardFeet(project);

  final doc = pw.Document(
    title: '${project.name} — cut list',
    author: 'Segmented Bowl Designer',
  );

  final mono = pw.Font.courier();
  final monoBold = pw.Font.courierBold();
  const accent = PdfColor.fromInt(0xFFB0741B);
  const ink = PdfColor.fromInt(0xFF2B2823);
  const faint = PdfColor.fromInt(0xFF726B5E);
  const panel = PdfColor.fromInt(0xFFF0E3CC);

  final headers = [
    'Ring',
    'Type',
    'Seg',
    'Miter',
    'Outer edge',
    'Inner edge',
    'Wall',
    'Height',
    'Board len',
    'Bd-ft',
  ];

  final rows = [
    for (final s in specs)
      [
        s.ring.name,
        s.solid ? 'solid' : s.ring.type.name,
        '${s.physicalSegments}',
        s.solid ? '—' : '${s.miterAngleDeg.toStringAsFixed(2)}°',
        v(s.outerEdgeMm),
        s.innerEdgeMm > 0 ? v(s.innerEdgeMm) : '—',
        v(s.wallWidthMm),
        v(s.thicknessMm),
        v(s.boardLengthMm),
        s.boardFeet.toStringAsFixed(2),
      ],
  ];

  final totalRow = [
    'TOTAL',
    '',
    '${project.totalSegments}',
    '',
    '',
    '',
    '',
    v(project.totalHeightMm),
    '',
    totalBf.toStringAsFixed(2),
  ];

  pw.Widget kv(String k, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: 18),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$k  ',
                style: pw.TextStyle(font: mono, fontSize: 9, color: faint)),
            pw.TextSpan(
                text: val,
                style: pw.TextStyle(font: monoBold, fontSize: 9, color: ink)),
          ]),
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(project.name,
                  style: pw.TextStyle(font: mono, fontSize: 8, color: faint)),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: mono, fontSize: 8, color: faint)),
      ),
      build: (context) => [
        pw.Text('Segmented Bowl Cut List',
            style: pw.TextStyle(fontSize: 20, color: ink, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(project.name, style: pw.TextStyle(fontSize: 12, color: accent)),
        pw.SizedBox(height: 10),
        pw.Wrap(children: [
          kv('Height', UnitFormat.withUnit(project.totalHeightMm, unit)),
          kv('Max ⌀', UnitFormat.withUnit(project.maxOuterDiameterMm, unit)),
          kv('Rings', '${project.rings.length}'),
          kv('Segments', '${project.totalSegments}'),
          kv('Board-feet', totalBf.toStringAsFixed(2)),
          kv('Units', unit.label),
        ]),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: [...rows, totalRow],
          border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(color: PdfColor.fromInt(0xFFD7D1C6), width: 0.5),
          ),
          headerStyle: pw.TextStyle(font: monoBold, fontSize: 8.5, color: ink),
          headerDecoration: const pw.BoxDecoration(color: panel),
          cellStyle: pw.TextStyle(font: mono, fontSize: 8.5, color: ink),
          cellHeight: 18,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            for (var i = 2; i < headers.length; i++) i: pw.Alignment.centerRight,
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFBFAF6)),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Board length includes a ${v(project.kerfAllowanceMm)} $u handling/kerf allowance '
          'per segment. Miter angle is 180/segments; a gap does not change it. '
          'Edge lengths are the flat cut length at the outer/inner radius.',
          style: pw.TextStyle(font: mono, fontSize: 8, color: faint),
        ),
      ],
    ),
  );

  return doc.save();
}
