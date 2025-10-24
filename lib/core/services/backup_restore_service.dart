import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

// Conditional import for web functionality
import 'backup_restore_service_stub.dart'
    if (dart.library.html) 'backup_restore_service_web.dart';

/// Backup & Restore Service
/// Creates backups of all important data and restores from backups
/// 
/// Usage:
/// ```dart
/// await BackupRestoreService.createBackup();
/// await BackupRestoreService.restoreFromBackup();
/// ```
class BackupRestoreService {
  static final _supabase = Supabase.instance.client;
  
  /// Tables to backup
  static const List<String> _tablesToBackup = [
    'users',
    'books',
    'courses',
    'jobs',
    'catalog_products',
    'distributor_products',
    'vet_supplies',
    'offers',
    'surgical_tools',
  ];
  
  /// Create full backup
  static Future<void> createBackup({BuildContext? context}) async {
    try {
      _showProgress(context, 'Creating backup...');
      
      final backupData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'tables': <String, dynamic>{},
      };
      
      // Backup each table
      for (var i = 0; i < _tablesToBackup.length; i++) {
        final tableName = _tablesToBackup[i];
        _showProgress(
          context,
          'Backing up $tableName (${i + 1}/${_tablesToBackup.length})...',
        );
        
        try {
          final data = await _supabase.from(tableName).select();
          backupData['tables'][tableName] = data;
        } catch (e) {
          debugPrint('Failed to backup $tableName: $e');
          backupData['tables'][tableName] = [];
        }
      }
      
      // Convert to JSON
      final jsonString = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonString);
      
      // Download as JSON (no ZIP to avoid dependency)
      _downloadFile(
        jsonBytes,
        'fieldawy_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      
      if (context != null && context.mounted) {
        _showSuccess(context, 'Backup created successfully!');
      }
    } catch (e) {
      _showError(context, 'Backup failed: $e');
    }
  }
  
  /// Restore from backup
  static Future<void> restoreFromBackup({BuildContext? context}) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }
      
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _showError(context, 'Could not read file');
        return;
      }
      
      _showProgress(context, 'Reading backup file...');
      
      // Parse backup data (JSON only)
      final jsonString = utf8.decode(bytes);
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate backup
      if (!backupData.containsKey('tables')) {
        _showError(context, 'Invalid backup file');
        return;
      }
      
      // Show confirmation
      if (context != null) {
        final confirmed = await _showConfirmDialog(
          context,
          backupData['timestamp'] ?? 'Unknown date',
          (backupData['tables'] as Map).length,
        );
        
        if (!confirmed) return;
      }
      
      // Restore data
      final tables = backupData['tables'] as Map<String, dynamic>;
      var restoredCount = 0;
      
      for (var i = 0; i < tables.length; i++) {
        final entry = tables.entries.elementAt(i);
        final tableName = entry.key;
        final data = entry.value as List;
        
        _showProgress(
          context,
          'Restoring $tableName (${i + 1}/${tables.length})...',
        );
        
        try {
          if (data.isNotEmpty) {
            // Clear existing data (optional - dangerous!)
            // await _supabase.from(tableName).delete().neq('id', '00000000-0000-0000-0000-000000000000');
            
            // Insert in batches
            const batchSize = 100;
            for (var j = 0; j < data.length; j += batchSize) {
              final end = (j + batchSize < data.length) ? j + batchSize : data.length;
              final batch = data.sublist(j, end);
              
              await _supabase.from(tableName).upsert(batch);
            }
            
            restoredCount++;
          }
        } catch (e) {
          debugPrint('Failed to restore $tableName: $e');
        }
      }
      
      _showSuccess(
        context,
        'Restored $restoredCount tables successfully!',
      );
    } catch (e) {
      _showError(context, 'Restore failed: $e');
    }
  }
  
  /// Download file (Web)
  static void _downloadFile(Uint8List bytes, String filename) {
    if (kIsWeb) {
      downloadBackupWeb(filename, bytes);
    }
  }
  
  /// Show confirmation dialog
  static Future<bool> _showConfirmDialog(
    BuildContext context,
    String backupDate,
    int tableCount,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Restore Backup?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will restore data from:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: $backupDate'),
            Text('Tables: $tableCount'),
            const SizedBox(height: 16),
            const Text(
              'Warning: This may overwrite existing data!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Show progress
  static void _showProgress(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  
  /// Show success
  static void _showSuccess(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Show error
  static void _showError(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
