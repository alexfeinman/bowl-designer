// Platform-neutral entry point for writing a file to disk / downloads.
// Desktop opens a native save dialog; web triggers a browser download.
export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
