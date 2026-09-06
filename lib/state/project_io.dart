import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/bowl_project.dart';
import 'file_saver.dart';

/// Save and open bowl design documents (`.sbowl`, JSON) across web + desktop.
class ProjectIo {
  const ProjectIo._();

  static const String extension = 'sbowl';

  /// Cut-list exports append this to the base name.
  static const String cutListSuffix = '-cutlist';

  /// Make [name] safe for a filename base (no extension).
  static String sanitize(String name) {
    final base = name.trim().isEmpty ? 'bowl' : name.trim();
    return base.replaceAll(RegExp(r'[^\w\- ]'), '_');
  }

  /// Recover the base name the user ended up with from a saved [filename],
  /// stripping the extension and, if present, the [suffix] we appended (e.g.
  /// "-cutlist" or " 3d"). Used to detect a rename in the save dialog.
  static String baseFromFilename(String filename, String suffix) {
    var s = filename;
    final dot = s.lastIndexOf('.');
    if (dot > 0) s = s.substring(0, dot);
    if (suffix.isNotEmpty && s.endsWith(suffix)) {
      s = s.substring(0, s.length - suffix.length);
    }
    return s.trim();
  }

  /// Serialize [project] to pretty JSON and save it under [baseName]. Returns
  /// the file name actually written, or null if cancelled.
  static Future<String?> save(BowlProject project, String baseName) async {
    final json = const JsonEncoder.withIndent('  ').convert(project.toJson());
    return saveBytes(
      '${sanitize(baseName)}.$extension',
      utf8.encode(json),
      typeLabel: 'Bowl design',
      extensions: const [extension, 'json'],
    );
  }

  /// Export cut-list [csv] under [baseName]. Returns the file name written, or
  /// null if cancelled.
  static Future<String?> exportCsv(String csv, String baseName) async {
    return saveBytes(
      '${sanitize(baseName)}$cutListSuffix.csv',
      utf8.encode(csv),
      typeLabel: 'CSV',
      extensions: const ['csv'],
    );
  }

  /// Save cut-list PDF [bytes] under [baseName]. Returns the file name written,
  /// or null if cancelled.
  static Future<String?> exportPdf(List<int> bytes, String baseName) async {
    return saveBytes(
      '${sanitize(baseName)}$cutListSuffix.pdf',
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
