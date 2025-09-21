// ignore: unused_import
import 'dart:io';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../widgets/shimmer_loader.dart';
import '../../application/document_upload_controller.dart';
import '../../domain/user_role.dart';
import 'profile_completion_screen.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const DocumentUploadScreen({super.key, required this.role});

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  bool _isUploading = false;

  Future<void> _onNextPressed() async {
    final selectedImage = ref.read(documentUploadControllerProvider);
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'تنبيه',
            message: 'pleaseSelectImageFirst'.tr(),
            contentType: ContentType.warning,
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final downloadUrl = await ref
        .read(documentUploadControllerProvider.notifier)
        .uploadSelectedImage();

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (downloadUrl != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProfileCompletionScreen(
            documentUrl: downloadUrl,
            selectedRole: widget.role.asString,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'خطأ',
            message: 'imageUploadFailed'.tr(),
            contentType: ContentType.failure,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = widget.role == UserRole.doctor
        ? 'uploadSyndicateCard'.tr()
        : 'uploadNationalId'.tr();

    final selectedImage = ref.watch(documentUploadControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('identityVerification'.tr()),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(selectedImage, fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Icon(Icons.image_outlined,
                            size: 80, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(documentUploadControllerProvider.notifier)
                      .pickImage(ImageSource.camera, context),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text('camera'.tr()),
                ),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(documentUploadControllerProvider.notifier)
                      .pickImage(ImageSource.gallery, context),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('gallery'.tr()),
                ),
              ],
            ),
            const Spacer(),
            if (_isUploading)
              const Center(
                  child: ShimmerLoader(
                width: 40,
                height: 40,
                isCircular: true,
              ))
            else
              ElevatedButton(
                onPressed: _onNextPressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text('next'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}
