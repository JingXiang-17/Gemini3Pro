import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// This magically routes to the Web version if compiled for Web, 
// and the Stub (Mobile) version if compiled for Mobile.
import 'file_viewer_stub.dart' if (dart.library.html) 'file_viewer_web.dart';

void openPlatformFile(BuildContext context, PlatformFile file) {
  openFileImpl(context, file);
}