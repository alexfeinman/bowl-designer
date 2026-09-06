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
  await File(location.path).writeAsBytes(Uint8List.fromList(bytes));
  return location.path.split(RegExp(r'[/\\]')).last;
}
