// Platform-neutral autosave: localStorage on web, an app-support file on
// desktop. Restores the last design on launch so work survives a reload.
export 'local_store_io.dart' if (dart.library.js_interop) 'local_store_web.dart';
