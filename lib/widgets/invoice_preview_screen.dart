import 'dart:typed_data';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:easy_localization/easy_localization.dart';
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
    final hasMultiplePages = imageBytesList.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الفاتورة'),
        actions: [
          IconButton(
            icon: Icon(Icons.save_alt_outlined,
                color: Theme.of(context).colorScheme.secondary),
            onPressed: () async {
              try {
                int savedCount = 0;
                for (final imageBytes in imageBytesList) {
                  await Gal.putImageBytes(imageBytes,
                      album: 'Fieldawy Invoices');
                  savedCount++;
                }
                if (context.mounted) {
                  final snackBar = SnackBar(
                    elevation: 0,
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.transparent,
                    content: AwesomeSnackbarContent(
                      title: 'نجاح'.tr(),
                      message: 'تم حفظ $savedCount صفحة بنجاح في معرض الصور',
                      contentType: ContentType.success,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              } catch (e) {
                if (context.mounted) {
                  final snackBar = SnackBar(
                    elevation: 0,
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.transparent,
                    content: AwesomeSnackbarContent(
                      title: 'خطأ'.tr(),
                      message: 'حدث خطأ أثناء الحفظ: $e',
                      contentType: ContentType.failure,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              }
            },
          ),
          if (whatsappNumber != null && whatsappNumber!.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
              onPressed: () async {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('إرسال عبر واتساب'),
                        content: const Text(
                          'سيتم فتح واتساب الموزع.\nقم بإرفاق صورة الفاتورة يدويًا قبل الإرسال.',
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
                                    final snackBar = SnackBar(
                                      elevation: 0,
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.transparent,
                                      content: AwesomeSnackbarContent(
                                        title: 'خطأ'.tr(),
                                        message:
                                            'تعذر فتح واتساب. يرجى التأكد من تثبيت التطبيق.',
                                        contentType: ContentType.failure,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(snackBar);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  final snackBar = SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: 'خطأ'.tr(),
                                      message:
                                          'حدث خطأ أثناء محاولة فتح واتساب: $e',
                                      contentType: ContentType.failure,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
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
      body: hasMultiplePages
          ? ListView.builder(
              itemCount: imageBytesList.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.memory(
                      imageBytesList[index],
                      width: MediaQuery.of(context).size.width,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            )
          : Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.memory(
                  imageBytesList.first,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }
}
