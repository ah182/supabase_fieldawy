// Stub implementation for non-web platforms
// ignore: unused_import
import 'dart:typed_data';

/// Download file - stub for non-web platforms
void downloadFileWeb(String filename, List<int> bytes) {
  // This should never be called on non-web platforms
  throw UnsupportedError('File download is only supported on web platform');
}
