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
  // Suggest the base WITHOUT our extension. An unregistered extension like
  // ".sbowl" is not recognised by the macOS save panel, so if we leave it on
  // the suggested name the panel treats the whole thing as the base and appends
  // the accepted extension again — showing "Bowl.sbowl.sbowl". Handing over a
  // bare base lets the panel add the extension exactly once.
  final suggestedBase = stripAcceptedExtension(filename, extensions);
  final location = await getSaveLocation(
    suggestedName: suggestedBase,
    acceptedTypeGroups: [XTypeGroup(label: typeLabel, extensions: extensions)],
  );
  if (location == null) return null;
  // Enforce exactly one accepted extension on the result: collapse a double
  // (belt and braces), and add one if the platform left it off (GTK doesn't).
  final path = withSingleExtension(location.path, extensions);
  await File(path).writeAsBytes(Uint8List.fromList(bytes));
  return path.split(RegExp(r'[/\\]')).last;
}

/// Drop a single trailing accepted extension from [name], if present.
/// Public for testing.
String stripAcceptedExtension(String name, List<String> extensions) {
  for (final ext in extensions) {
    final dotExt = '.$ext';
    if (name.toLowerCase().endsWith(dotExt.toLowerCase())) {
      return name.substring(0, name.length - dotExt.length);
    }
  }
  return name;
}

/// Ensure [path] ends with exactly one accepted extension: collapse any doubles,
/// then append the primary extension if none of the accepted ones is present.
/// Public for testing.
String withSingleExtension(String path, List<String> extensions) {
  var p = path;
  for (final ext in extensions) {
    final doubled = '.$ext.$ext';
    while (p.toLowerCase().endsWith(doubled.toLowerCase())) {
      p = p.substring(0, p.length - ext.length - 1); // drop one ".$ext"
    }
  }
  final hasExt = extensions
      .any((e) => p.toLowerCase().endsWith('.${e.toLowerCase()}'));
  return hasExt ? p : '$p.${extensions.first}';
}
