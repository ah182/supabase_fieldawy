// Stub implementation for non-web platforms
import 'dart:typed_data';

/// Download backup - stub for non-web platforms
void downloadBackupWeb(String filename, Uint8List bytes) {
  throw UnsupportedError('Backup download is only supported on web platform');
}

/// Upload file picker - stub for non-web platforms
Future<Uint8List?> pickFileWeb() async {
  throw UnsupportedError('File picker is only supported on web platform');
}
