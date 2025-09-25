
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
      pw.Page(
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        pageFormat: PdfPageFormat.a4,
        
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                // Header
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

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey700),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.75),   // Total (الإجمالي)
                    1: const pw.FlexColumnWidth(1.5), // Quantity (الكمية)
                    2: const pw.FlexColumnWidth(1.5), // Price (السعر)
                    3: const pw.FlexColumnWidth(1.25), // Package Size (حجم العبوة)
                    4: const pw.FlexColumnWidth(1.5),   // Product (المنتج)
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('المنتج',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('حجم العبوة', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('السعر', textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),
                        
                                                pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('الكمية',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),

                                                pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('الإجمالي',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold))),

                      ] 
                    ),
                    // Product Rows
                    ...products.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final product = entry.value;
                      final double price = product['price'] ?? 0.0;
                      final int quantity = product['quantity'] ?? 0;
                      final double subtotal = price * quantity;
                      final color = index % 2 == 0 ? PdfColors.white : PdfColors.grey100;

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: color),
                        children: [
                           pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(product['name'] ?? '',
                                    textAlign: pw.TextAlign.left)),
                           pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(product['selectedPackage'] ?? '',
                                    textAlign: pw.TextAlign.center)),
                                                     pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(price.toStringAsFixed(2),
                                    textAlign: pw.TextAlign.center)),
         
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(quantity.toString(), textAlign: pw.TextAlign.center)),
                                                    pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(subtotal.toStringAsFixed(2),
                                    textAlign: pw.TextAlign.center)),

                        ]
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Total
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
                
                pw.SizedBox(height: 40),

                pw.Center(
                  
                  child: pw.Text('شكراً لتعاملكم معنا - Thank you for your business', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 14))
                )
                
              ],
              
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}

