import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/storage_service.dart';
import '../../../features/authentication/services/auth_service.dart';

class DocumentUploadController extends StateNotifier<File?> {
  final Ref _ref;

  DocumentUploadController(this._ref) : super(null);

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage(ImageSource source, BuildContext context) async {
    if (source == ImageSource.camera) {
      final permission = Permission.camera;
      final PermissionStatus status = await permission.request();

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('الصلاحية مطلوبة'),
                content: const Text(
                    'لإكمال هذه العملية، الرجاء تمكين صلاحية الوصول للكاميرا يدويا من إعدادات التطبيق.'),
                actions: [
                  TextButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text('فتح الإعدادات'),
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          }
        }
        return;
      }
    }

    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        state = File(pickedFile.path);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<String?> uploadSelectedImage() async {
    if (state == null) return null;
    final userId = _ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return null;
    final storageService = _ref.read(storageServiceProvider);
    // رفع المستند إلى فولدر 'documents' في Supabase Storage
    return await storageService.uploadDocument(state!, 'documents');
  }

  void clearImage() {
    state = null;
  }
}

final documentUploadControllerProvider =
    StateNotifierProvider<DocumentUploadController, File?>((ref) {
  return DocumentUploadController(ref);
});
