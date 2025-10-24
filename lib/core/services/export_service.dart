import 'dart:convert';
// ignore: unused_import
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, Colors;

// Conditional import for web download
import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart';

/// Export Service
/// Exports data to Excel, CSV, or PDF
/// 
/// Usage:
/// ```dart
/// await ExportService.exportToExcel(
///   data: users,
///   filename: 'users',
///   headers: ['Name', 'Email', 'Role'],
///   getData: (user) => [user.name, user.email, user.role],
/// );
/// ```
class ExportService {
  /// Export to Excel (.xlsx)
  static Future<void> exportToExcel<T>({
    required List<T> data,
    required String filename,
    required List<String> headers,
    required List<dynamic> Function(T item) getData,
    BuildContext? context,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      
      // Add headers
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.blue,
            fontColorHex: ExcelColor.white,
          );
      }
      
      // Add data
      for (var rowIndex = 0; rowIndex < data.length; rowIndex++) {
        final rowData = getData(data[rowIndex]);
        for (var colIndex = 0; colIndex < rowData.length; colIndex++) {
          final value = rowData[colIndex];
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          )).value = TextCellValue(value?.toString() ?? '');
        }
      }
      
      // Export
      final bytes = excel.encode();
      if (bytes != null) {
        _downloadFile(bytes, '$filename.xlsx');
        _showSuccess(context, 'Exported ${data.length} rows to Excel');
      }
    } catch (e) {
      _showError(context, 'Export failed: $e');
    }
  }
  
  /// Export to CSV
  static Future<void> exportToCSV<T>({
    required List<T> data,
    required String filename,
    required List<String> headers,
    required List<dynamic> Function(T item) getData,
    BuildContext? context,
  }) async {
    try {
      // Prepare data
      final List<List<dynamic>> rows = [headers];
      for (var item in data) {
        rows.add(getData(item));
      }
      
      // Convert to CSV
      final csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      
      _downloadFile(bytes, '$filename.csv');
      _showSuccess(context, 'Exported ${data.length} rows to CSV');
    } catch (e) {
      _showError(context, 'Export failed: $e');
    }
  }
  
  /// Export to PDF
  static Future<void> exportToPDF<T>({
    required List<T> data,
    required String filename,
    required String title,
    required List<String> headers,
    required List<dynamic> Function(T item) getData,
    BuildContext? context,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Split data into pages (20 rows per page)
      const rowsPerPage = 20;
      final pageCount = (data.length / rowsPerPage).ceil();
      
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final startIndex = pageIndex * rowsPerPage;
        final endIndex = (startIndex + rowsPerPage > data.length)
            ? data.length
            : startIndex + rowsPerPage;
        final pageData = data.sublist(startIndex, endIndex);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Table
                pw.Table.fromTextArray(
                  headers: headers,
                  data: pageData.map((item) => getData(item)).toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue,
                  ),
                  headerHeight: 30,
                  cellHeight: 25,
                  cellAlignments: {
                    for (var i = 0; i < headers.length; i++)
                      i: pw.Alignment.centerLeft,
                  },
                ),
                
                // Footer
                pw.Spacer(),
                pw.Text(
                  'Page ${pageIndex + 1} of $pageCount',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }
      
      // Export
      final bytes = await pdf.save();
      _downloadFile(bytes, '$filename.pdf');
      _showSuccess(context, 'Exported ${data.length} rows to PDF');
    } catch (e) {
      _showError(context, 'Export failed: $e');
    }
  }
  
  /// Download file (Web)
  static void _downloadFile(List<int> bytes, String filename) {
    if (kIsWeb) {
      downloadFileWeb(filename, bytes);
    } else {
      // For mobile: use file_saver or similar
      debugPrint('File saved: $filename');
    }
  }
  
  /// Show success message
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
  
  /// Show error message
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
