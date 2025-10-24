import 'package:flutter/material.dart';
import 'package:fieldawy_store/core/services/export_service.dart';

/// Reusable toolbar with Export actions
class DataActionsToolbar extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final VoidCallback? onRefresh;

  const DataActionsToolbar({
    super.key,
    required this.title,
    required this.data,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // Actions
          Wrap(
            spacing: 8,
            children: [
              // Export to Excel
              OutlinedButton.icon(
                onPressed: data.isEmpty
                    ? null
                    : () {
                        if (data.isEmpty) return;
                        final headers = data.first.keys.toList();
                        ExportService.exportToExcel(
                          data: data,
                          filename: title,
                          headers: headers,
                          getData: (item) => headers.map((key) => item[key]).toList(),
                        );
                      },
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Excel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.green,
                ),
              ),
              // Export to CSV
              OutlinedButton.icon(
                onPressed: data.isEmpty
                    ? null
                    : () {
                        if (data.isEmpty) return;
                        final headers = data.first.keys.toList();
                        ExportService.exportToCSV(
                          data: data,
                          filename: title,
                          headers: headers,
                          getData: (item) => headers.map((key) => item[key]).toList(),
                        );
                      },
                icon: const Icon(Icons.description, size: 16),
                label: const Text('CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.blue,
                ),
              ),
              // Export to PDF
              OutlinedButton.icon(
                onPressed: data.isEmpty
                    ? null
                    : () {
                        if (data.isEmpty) return;
                        final headers = data.first.keys.toList();
                        ExportService.exportToPDF(
                          data: data,
                          filename: title,
                          headers: headers,
                          getData: (item) => headers.map((key) => item[key]).toList(),
                          title: title,
                        );
                      },
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.red,
                ),
              ),
              // Refresh
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
