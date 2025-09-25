import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';





class InvoicePreviewScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final Uint8List pdfBytes;
  final String? whatsappNumber;

  const InvoicePreviewScreen({super.key, required this.imageBytes, required this.pdfBytes, this.whatsappNumber});

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
                await Gal.putImageBytes(imageBytes, album: 'Fieldawy Invoices');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم حفظ الفاتورة بنجاح في معرض الصور')),
                  );
                  Navigator.of(context).pop();
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
              icon: Icon(FontAwesomeIcons.whatsapp),
              onPressed: () async {
                try {
                  final message = 'مرحباً، إليك فاتورتك.'; // Pre-filled message
                  final whatsappUrl = 'https://api.whatsapp.com/send?phone=20$whatsappNumber&text=${Uri.encodeComponent(message)}';

                  if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                    await launchUrl(Uri.parse(whatsappUrl));
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح واتساب.')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            imageBytes,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
