import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final List<Uint8List> imageBytesList;
  final Uint8List pdfBytes;
  final String? whatsappNumber;

  const InvoicePreviewScreen({
    super.key,
    required this.imageBytesList,
    required this.pdfBytes,
    this.whatsappNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الفاتورة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: () async {
              try {
                int savedCount = 0;
                for (final imageBytes in imageBytesList) {
                  await Gal.putImageBytes(imageBytes,
                      album: 'Fieldawy Invoices');
                  savedCount++;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('تم حفظ $savedCount صفحة بنجاح في معرض الصور'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
                  );
                }
              }
            },
          ),
          if (whatsappNumber != null && whatsappNumber!.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.whatsapp),
              onPressed: () async {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('إرسال عبر واتساب'),
                        content: const Text(
                          'سيتم فتح واتساب مع رسالة مكتوبة مسبقًا.\n'
                          'بعد الفتح قم بإرفاق صورة الفاتورة يدويًا قبل الإرسال (يمكنك إرفاق أول صفحة).',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('إلغاء'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          ElevatedButton(
                            child: const Text('متابعة'),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              try {
                                final message = 'مرحباً، إليك فاتورتك.';
                                final whatsappUrl =
                                    'https://api.whatsapp.com/send?phone=20$whatsappNumber&text=${Uri.encodeComponent(message)}';

                                if (await canLaunchUrl(
                                    Uri.parse(whatsappUrl))) {
                                  await launchUrl(Uri.parse(whatsappUrl));
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تعذر فتح واتساب.'),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'حدث خطأ أثناء إرسال الرسالة: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: imageBytesList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                if (imageBytesList.length > 1)
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.memory(
                      imageBytesList[index],
                      width: MediaQuery.of(context).size.width,
                      fit: BoxFit.contain,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
