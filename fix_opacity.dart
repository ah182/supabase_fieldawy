
import 'dart:io';

void main() {
  final directory = Directory('lib'); // Adjust if checking other dirs
  if (!directory.existsSync()) {
    print('Directory lib not found');
    return;
  }

  // Regex to match .withOpacity(value)
  // Captures the value inside the parentheses
  final regex = RegExp(r'\.withOpacity\(([^)]+)\)');

  int totalReplacements = 0;

  void processFile(File file) {
    if (!file.path.endsWith('.dart')) return;
    
    String content = file.readAsStringSync();
    String newContent = content.replaceAllMapped(regex, (match) {
      final opacityValue = match.group(1);
      return '.withValues(alpha: $opacityValue)';
    });

    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Updated: ${file.path}');
      totalReplacements++;
    }
  }

  void processDirectory(Directory dir) {
    for (var entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        processFile(entity);
      }
    }
  }

  processDirectory(directory);
  print('Total files updated: $totalReplacements (estimation, duplicates possible if multiple per file)');
}
