import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class InvoiceService {
  Future<Uint8List> createInvoice(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final DateTime orderDate = DateTime.parse(order['date']);
    final String distributorName = order['distributorName'] ?? 'N/A';
    final String clientName = order['clientName'] ?? 'N/A';
    final List<dynamic> products = order['products'] ?? [];
    final double total = order['total'] ?? 0.0;
    final formattedDate = DateFormat('yyyy-MM-dd').format(orderDate);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('فاتورة مبيعات', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sales Invoice', style: const pw.TextStyle(fontSize: 18)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('التاريخ: $formattedDate'),
                  pw.Spacer(),
                  pw.Text('الموزع: $distributorName'),
                  pw.Spacer(),
                  pw.Text('العميل: $clientName'),
                ]
              ),
              pw.Divider(height: 30),
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
          final headers = ['المنتج', 'حجم العبوة', 'السعر', 'الكمية', 'الإجمالي'];

          final data = products.map((product) {
            final double price = product['price'] ?? 0.0;
            final int quantity = product['quantity'] ?? 0;
            final double subtotal = price * quantity;
            return [
              product['name'] ?? '',
              product['selectedPackage'] ?? '',
              price.toStringAsFixed(2),
              quantity.toString(),
              subtotal.toStringAsFixed(2),
            ];
          }).toList();

          return [
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey700),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                 0: pw.Alignment.centerLeft,
                 1: pw.Alignment.center,
                 2: pw.Alignment.center,
                 3: pw.Alignment.center,
                 4: pw.Alignment.center,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(1.75),   // Product
                1: const pw.FlexColumnWidth(1.5), // Package
                2: const pw.FlexColumnWidth(1.5),  // Price
                3: const pw.FlexColumnWidth(1.25),  // Quantity
                4: const pw.FlexColumnWidth(1.5), // Total
              },
              headers: headers,
              data: data,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
            pw.Spacer(), // Use a spacer to push content to the bottom
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'المجموع النهائي:',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    '${total.toStringAsFixed(2)} ج.م',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text('شكراً لتعاملكم معنا - Thank you for your business', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 14))
            )
          ];
        },
      ),
    );

    return pdf.save();
  }
}