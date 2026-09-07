import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Desktop/native save: prompt for a location and write [bytes].
/// Returns the file name the user actually chose (its last path segment, so a
/// rename in the dialog is visible to the caller), or null if they cancelled.
Future<String?> saveBytes(
  String filename,
  List<int> bytes, {
  required String typeLabel,
  required List<String> extensions,
}) async {
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [XTypeGroup(label: typeLabel, extensions: extensions)],
  );
  if (location == null) return null;
  final path = _collapseDoubledExtension(location.path, extensions);
  await File(path).writeAsBytes(Uint8List.fromList(bytes));
  return path.split(RegExp(r'[/\\]')).last;
}

/// Some save panels (notably macOS NSSavePanel) append the type extension to a
/// suggested name that already carried it, yielding e.g. "Bowl.sbowl.sbowl".
/// Collapse a doubled accepted extension so the file — and the name reported to
/// callers — carries it exactly once. A no-op when there's no doubling.
String _collapseDoubledExtension(String path, List<String> extensions) {
  var p = path;
  for (final ext in extensions) {
    final doubled = '.$ext.$ext';
    while (p.toLowerCase().endsWith(doubled.toLowerCase())) {
      p = p.substring(0, p.length - ext.length - 1); // drop one ".$ext"
    }
  }
  return p;
}
