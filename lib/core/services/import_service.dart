import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Import Service
/// Imports data from CSV files
/// 
/// Usage:
/// ```dart
/// await ImportService.importFromCSV(
///   tableName: 'products',
///   requiredHeaders: ['name', 'price', 'description'],
///   parseRow: (row) => {
///     'name': row['name'],
///     'price': double.parse(row['price'] ?? '0'),
///     'description': row['description'],
///   },
/// );
/// ```
class ImportService {
  static final _supabase = Supabase.instance.client;
  
  /// Import from CSV file
  static Future<ImportResult> importFromCSV({
    required String tableName,
    required List<String> requiredHeaders,
    required Map<String, dynamic> Function(Map<String, dynamic> row) parseRow,
    BuildContext? context,
  }) async {
    try {
      // 1. Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: false,
          message: 'No file selected',
        );
      }
      
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        return ImportResult(
          success: false,
          message: 'Could not read file',
        );
      }
      
      // 2. Parse CSV
      final csvData = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(csvData);
      
      if (rows.isEmpty) {
        return ImportResult(
          success: false,
          message: 'File is empty',
        );
      }
      
      // 3. Validate headers
      final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
      final missingHeaders = requiredHeaders
          .where((required) => !headers.contains(required.toLowerCase()))
          .toList();
      
      if (missingHeaders.isNotEmpty) {
        return ImportResult(
          success: false,
          message: 'Missing required columns: ${missingHeaders.join(", ")}',
        );
      }
      
      // 4. Parse rows
      final dataRows = rows.skip(1).toList();
      final List<Map<String, dynamic>> parsedData = [];
      final List<String> errors = [];
      
      for (var i = 0; i < dataRows.length; i++) {
        try {
          final row = dataRows[i];
          final rowMap = <String, dynamic>{};
          
          for (var j = 0; j < headers.length; j++) {
            if (j < row.length) {
              rowMap[headers[j]] = row[j];
            }
          }
          
          final parsed = parseRow(rowMap);
          parsedData.add(parsed);
        } catch (e) {
          errors.add('Row ${i + 2}: $e');
        }
      }
      
      if (parsedData.isEmpty) {
        return ImportResult(
          success: false,
          message: 'No valid data found',
          errors: errors,
        );
      }
      
      // 5. Show preview dialog
      if (context != null) {
        final confirmed = await _showPreviewDialog(
          context: context,
          data: parsedData,
          errors: errors,
        );
        
        if (!confirmed) {
          return ImportResult(
            success: false,
            message: 'Import cancelled by user',
          );
        }
      }
      
      // 6. Insert to Supabase (batch)
      final batchSize = 100;
      var insertedCount = 0;
      
      for (var i = 0; i < parsedData.length; i += batchSize) {
        final end = (i + batchSize < parsedData.length)
            ? i + batchSize
            : parsedData.length;
        final batch = parsedData.sublist(i, end);
        
        await _supabase.from(tableName).insert(batch);
        insertedCount += batch.length;
        
        // Show progress
        if (context != null) {
          _showProgress(context, insertedCount, parsedData.length);
        }
      }
      
      return ImportResult(
        success: true,
        message: 'Successfully imported $insertedCount records',
        insertedCount: insertedCount,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }
  
  /// Show preview dialog
  static Future<bool> _showPreviewDialog({
    required BuildContext context,
    required List<Map<String, dynamic>> data,
    required List<String> errors,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Preview'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${data.length} valid records',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${errors.length} errors found',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Preview (first 5 records):'),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.take(5).map((row) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(row.toString()),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Errors:', style: TextStyle(color: Colors.red)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.take(5).map((error) {
                        return Text(
                          error,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Show progress
  static void _showProgress(BuildContext context, int current, int total) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing: $current/$total'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}

/// Import result
class ImportResult {
  final bool success;
  final String message;
  final int insertedCount;
  final List<String> errors;
  
  ImportResult({
    required this.success,
    required this.message,
    this.insertedCount = 0,
    this.errors = const [],
  });
}
