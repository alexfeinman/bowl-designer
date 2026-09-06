import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web save: trigger a browser download of [bytes] as [filename].
/// Returns [filename] (the browser handles the destination and never reports a
/// rename back, so the suggested name is the effective one).
Future<String?> saveBytes(
  String filename,
  List<int> bytes, {
  required String typeLabel,
  required List<String> extensions,
}) async {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    [data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return filename;
}
