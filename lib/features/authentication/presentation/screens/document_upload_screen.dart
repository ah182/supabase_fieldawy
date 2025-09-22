// ignore: unused_import
import 'dart:io';


import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart'; // Add this package to pubspec.yaml

import '../../application/document_upload_controller.dart';
import '../../domain/user_role.dart';
import 'profile_completion_screen.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  final UserRole role;
  final List<String> governorates;
  final List<String> centers;
  const DocumentUploadScreen(
      {super.key,
      required this.role,
      required this.governorates,
      required this.centers});

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }


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



    _showLoadingDialog();

    final downloadUrl = await ref
        .read(documentUploadControllerProvider.notifier)
        .uploadSelectedImage();

    _hideLoadingDialog();
    if (!mounted) return;



    if (downloadUrl != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProfileCompletionScreen(
            documentUrl: downloadUrl,
            selectedRole: widget.role.asString,
            governorates: widget.governorates,
            centers: widget.centers,
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
    // A more professional color palette
    const Color kPrimaryColor = Color(0xFF0D47A1); // Deep Blue
    // Light Gray background
    const Color kTextColor = Color(0xFF0F172A); // Almost Black
    const Color kMutedTextColor = Color(0xFF64748B);

    final textTheme = Theme.of(context).textTheme;
    final title = widget.role == UserRole.doctor
        ? 'uploadSyndicateCard'.tr()
        : 'uploadNationalId'.tr();

    final selectedImage = ref.watch(documentUploadControllerProvider);
    final isImageSelected = selectedImage != null;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 251, 251, 251),
      appBar: AppBar(
        
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header Text ---
            Text(
              'identityVerification'.tr(),
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: kTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(color: kMutedTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // --- Image Uploader Box ---
            AspectRatio(
              aspectRatio: 16 / 10,
              child: DottedBorder(
                color: isImageSelected
                    ? Colors.green.shade400
                    : Colors.grey.shade400,
                strokeWidth: 2,
                dashPattern: const [8, 4],
                borderType: BorderType.RRect,
                radius: const Radius.circular(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isImageSelected
                        ? Colors.green.withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(selectedImage, fit: BoxFit.contain),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.green.shade600,
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 20),
                                ),
                              )
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 60, color: Colors.grey.shade500),
                              const SizedBox(height: 8),
                             
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Action Buttons (Camera & Gallery) ---
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    context,
                    icon: Icons.camera_alt_outlined,
                    label: 'camera'.tr(),
                    onPressed: () => ref
                        .read(documentUploadControllerProvider.notifier)
                        .pickImage(ImageSource.camera, context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerButton(
                    context,
                    icon: Icons.photo_library_outlined,
                    label: 'gallery'.tr(),
                    onPressed: () => ref
                        .read(documentUploadControllerProvider.notifier)
                        .pickImage(ImageSource.gallery, context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Instruction Card ---
            _buildInstructionCard(context, textTheme, kMutedTextColor),
            const SizedBox(height: 100), // Space for the bottom button
          ],
        ),
      ),
      // --- Bottom Navigation / Action Button ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
                onPressed: isImageSelected ? _onNextPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: Text('next'.tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  Widget _buildPickerButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0D47A1),
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInstructionCard(
      BuildContext context, TextTheme textTheme, Color kMutedTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ensure Image Clarity'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  'image Tips'.tr(),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: kMutedTextColor, height: 1.5),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
