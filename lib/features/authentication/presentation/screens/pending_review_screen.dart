import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class PendingReviewScreen extends ConsumerWidget {
  const PendingReviewScreen({super.key});

  Future<void> _contactSupport(BuildContext context, WidgetRef ref) async {
    // 1. جلب الاسم والبريد الإلكتروني للمستخدم الحالي
    final user = ref.read(authServiceProvider).currentUser;
    final userName = user?.userMetadata?['name'] ?? 'غير متوفر';
    final userEmail = user?.email ?? 'غير متوفر';

    // 2. إنشاء نص الرسالة مع تمرير البيانات
    final message = 'auth.pending.support_message'.tr(namedArgs: {
      'name': userName,
      'email': userEmail,
    });

    final encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/201017016217?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              content: AwesomeSnackbarContent(
                title: 'تنبيه',
                message: 'auth.pending.cannot_open_whatsapp'.tr(),
                contentType: ContentType.warning,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 80,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 24),
              Text(
                'auth.pending.account_under_review'.tr(),
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'auth.pending.pending_message'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => _contactSupport(context, ref),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('auth.pending.contact_support'.tr()),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(authServiceProvider).signOut();
                },
                child: Text('auth.pending.sign_out'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
