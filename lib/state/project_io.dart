import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/bowl_project.dart';
import 'file_saver.dart';

/// Save and open bowl design documents (`.sbowl`, JSON) across web + desktop.
class ProjectIo {
  const ProjectIo._();

  static const String extension = 'sbowl';

  static String _sanitize(String name) {
    final base = name.trim().isEmpty ? 'bowl' : name.trim();
    return base.replaceAll(RegExp(r'[^\w\- ]'), '_');
  }

  /// Serialize [project] to pretty JSON and save it. Returns true if written.
  static Future<bool> save(BowlProject project) async {
    final json = const JsonEncoder.withIndent('  ').convert(project.toJson());
    return saveBytes(
      '${_sanitize(project.name)}.$extension',
      utf8.encode(json),
      typeLabel: 'Bowl design',
      extensions: const [extension, 'json'],
    );
  }

  /// Export cut-list [csv] text to a file. Returns true if written.
  static Future<bool> exportCsv(String csv, String projectName) async {
    return saveBytes(
      '${_sanitize(projectName)}-cutlist.csv',
      utf8.encode(csv),
      typeLabel: 'CSV',
      extensions: const ['csv'],
    );
  }

  /// Save cut-list PDF [bytes] to a file. Returns true if written.
  static Future<bool> exportPdf(List<int> bytes, String projectName) async {
    return saveBytes(
      '${_sanitize(projectName)}-cutlist.pdf',
      bytes,
      typeLabel: 'PDF',
      extensions: const ['pdf'],
    );
  }

  /// Prompt for a `.sbowl`/JSON file and parse it. Null if cancelled.
  static Future<BowlProject?> open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Bowl design', extensions: [extension, 'json']),
      ],
    );
    if (file == null) return null;
    final content = await file.readAsString();
    return BowlProject.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
