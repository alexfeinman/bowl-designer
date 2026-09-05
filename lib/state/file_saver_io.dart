import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Desktop/native save: prompt for a location and write [bytes].
/// Returns true if the file was written, false if the user cancelled.
Future<bool> saveBytes(
  String filename,
  List<int> bytes, {
  required String typeLabel,
  required List<String> extensions,
}) async {
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [XTypeGroup(label: typeLabel, extensions: extensions)],
  );
  if (location == null) return false;
  await File(location.path).writeAsBytes(Uint8List.fromList(bytes));
  return true;
}
