import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/domain/user_role.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/document_upload_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/user_repository.dart';
import '../../services/auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class RejectionScreen extends ConsumerWidget {
  const RejectionScreen({super.key});

  Future<void> _contactSupport(BuildContext context, WidgetRef ref) async {
    // 1. جلب الاسم والبريد الإلكتروني للمستخدم الحالي
    final user = ref.read(authServiceProvider).currentUser;
    final userName = user?.userMetadata?['name'] ?? 'غير متوفر';


    // 2. إنشاء نص الرسالة مع تمرير البيانات
    final message = 'auth.rejection.support_message'.tr(namedArgs: {
      'name': userName,
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
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.orange.shade700,
              ),
              const SizedBox(height: 24),
              Text(
                'auth.rejection.documents_mismatch'.tr(),
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'auth.rejection.rejection_message'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
              // Show Rejection Reason if available
              Consumer(
                builder: (context, ref, child) {
                  final userDataAsync = ref.watch(userDataProvider);
                  return userDataAsync.when(
                    data: (user) {
                      if (user != null &&
                          user.rejectionReason != null &&
                          user.rejectionReason!.isNotEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'auth.rejection.reason'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.rejectionReason!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final user = ref.read(authServiceProvider).currentUser;
                  if (user != null) {
                    final userData = await ref
                        .read(userRepositoryProvider)
                        .getUser(user.id);

                    await ref
                        .read(userRepositoryProvider)
                        .reInitiateOnboarding(user.id);

                    if (context.mounted) {
                      if (userData != null) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => DocumentUploadScreen(
                              role: UserRoleHelper.fromString(userData.role),
                              governorates: userData.governorates ?? [],
                              centers: userData.centers ?? [],
                            ),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      } else {
                        // Fallback in case user data is missing (unlikely)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const AuthGate()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('auth.rejection.reupload_documents'.tr()),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _contactSupport(context, ref),
                child: Text('auth.pending.contact_support'.tr()),
              ),
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
