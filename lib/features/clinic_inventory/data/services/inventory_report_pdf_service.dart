import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/inventory_transaction.dart';
import '../models/clinic_inventory_item.dart';

class InventoryReportPdfService {
  Future<Uint8List> createReport({
    required DateTime date,
    required List<InventoryTransaction> transactions,
    required double totalSales,
    required double totalProfit,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('تقرير مبيعات',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sales Report',
                      style: const pw.TextStyle(fontSize: 18)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
                pw.Text('التاريخ: $formattedDate',
                    style: const pw.TextStyle(fontSize: 14)),
              ]),
              pw.Divider(height: 20),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10.0),
            child: pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12),
            ),
          );
        },
        build: (pw.Context context) {
          final headers = ['المنتج', 'الكمية', 'سعر البيع', 'المكسب'];

          final data = transactions
              .where((t) => t.transactionType == TransactionType.sell)
              .map((tx) {
            final productName = tx.productName ?? 'غير معروف';
            final unitDisplay = _getDetailedUnit(tx.unitSold, tx.package);
            final quantity =
                '${tx.quantitySold.toStringAsFixed(0)} $unitDisplay';
            final price = tx.sellingPrice?.toStringAsFixed(0) ?? '0';
            final profit = tx.profit?.toStringAsFixed(0) ?? '0';

            return [
              productName,
              quantity,
              price,
              profit,
            ];
          }).toList();

          return [
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey700),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // Product
                1: const pw.FlexColumnWidth(1), // Quantity
                2: const pw.FlexColumnWidth(1), // Price
                3: const pw.FlexColumnWidth(1), // Profit
              },
              headers: headers,
              data: data,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'إجمالي المبيعات: ${totalSales.toStringAsFixed(0)} ج',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'إجمالي الأرباح: ${totalProfit.toStringAsFixed(0)} ج',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _getDetailedUnit(String? unitSold, String? package) {
    if (unitSold == null) return '';

    String unit = unitSold;

    if (unit == 'box') {
      return 'علبة';
    } else if (unit == 'piece' || unit == 'unit') {
      if (package != null) {
        final lowerPkg = package.toLowerCase();
        if (lowerPkg.contains('ml')) return 'مل';
        if (lowerPkg.contains('gm') ||
            lowerPkg.contains(' g ') ||
            lowerPkg.endsWith(' g')) return 'جرام';
        if (lowerPkg.contains('mg')) return 'مجم';
        if (lowerPkg.contains('tab') || lowerPkg.contains('cap')) return 'قرص';
        if (lowerPkg.contains('amp')) return 'أمبول';
        if (lowerPkg.contains('vial')) return 'فيال';
      }
      return 'وحدة';
    }

    // Translations for other units if needed
    switch (unit) {
      case 'ml':
        return 'مل';
      case 'gram':
        return 'جرام';
      case 'tablet':
        return 'قرص';
      case 'capsule':
        return 'كبسولة';
      default:
        return unit;
    }
  }
}
