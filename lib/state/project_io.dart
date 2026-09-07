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

  /// Extensions this app appends when saving/exporting. Only these are stripped
  /// when recovering a base name, so a legitimate dot in a name (e.g. "v1.2")
  /// survives.
  static const List<String> _knownExtensions = [extension, 'json', 'csv', 'pdf', 'png'];

  /// Make [name] safe for a filename base (no extension).
  static String sanitize(String name) {
    final base = name.trim().isEmpty ? 'bowl' : name.trim();
    return base.replaceAll(RegExp(r'[^\w\- ]'), '_');
  }

  /// Recover the base name the user ended up with from a saved [filename],
  /// stripping our extension(s) and, if present, the [suffix] we appended (e.g.
  /// "-cutlist" or " 3d"). Used to detect a rename in the save dialog.
  ///
  /// Known extensions are stripped repeatedly: some platforms (macOS
  /// NSSavePanel via file_selector) append the type extension to a suggested
  /// name that already carried it, yielding e.g. "Fruit bowl.sbowl.sbowl" —
  /// which must collapse back to "Fruit bowl", not "Fruit bowl.sbowl".
  static String baseFromFilename(String filename, String suffix) {
    var s = filename.trim();
    for (var stripped = true; stripped;) {
      stripped = false;
      for (final ext in _knownExtensions) {
        final dotExt = '.$ext';
        if (s.toLowerCase().endsWith(dotExt) && s.length > dotExt.length) {
          s = s.substring(0, s.length - dotExt.length);
          stripped = true;
          break;
        }
      }
    }
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
