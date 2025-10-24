// Web-specific implementation for backup/restore
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Download backup file for web platform
void downloadBackupWeb(String filename, Uint8List bytes) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Upload file picker for web platform
Future<Uint8List?> pickFileWeb() async {
  final input = html.FileUploadInputElement()..accept = '.json';
  input.click();
  
  await input.onChange.first;
  
  if (input.files != null && input.files!.isNotEmpty) {
    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    return reader.result as Uint8List?;
  }
  
  return null;
}
