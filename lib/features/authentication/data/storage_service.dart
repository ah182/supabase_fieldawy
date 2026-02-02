import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// خدمة رفع الملفات إلى Supabase Storage
/// تستخدم لرفع صور البروفايل والمستندات
class StorageService {
  static const String _bucketName = 'docs&profiles';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// رفع مستند/صورة إلى Supabase Storage في فولدر محدد
  /// [image] - الملف المراد رفعه
  /// [folderName] - اسم الفولدر (مثل: profile_images, documents)
  /// يرجع رابط الصورة العام أو null في حال الفشل
  Future<String?> uploadDocument(File image, String folderName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ StorageService: User not authenticated');
        return null;
      }

      // إنشاء اسم فريد للملف
      final extension = path.extension(image.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$folderName/${userId}_$timestamp$extension';

      // قراءة الملف
      final bytes = await image.readAsBytes();

      // تحديد نوع الملف
      String contentType = 'image/jpeg';
      if (extension == '.png') {
        contentType = 'image/png';
      } else if (extension == '.gif') {
        contentType = 'image/gif';
      } else if (extension == '.webp') {
        contentType = 'image/webp';
      } else if (extension == '.pdf') {
        contentType = 'application/pdf';
      }

      // رفع الملف إلى Supabase Storage
      await _supabase.storage.from(_bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true, // استبدال الملف إذا كان موجوداً
            ),
          );

      // الحصول على الرابط العام
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      print('✅ StorageService: File uploaded successfully to $fileName');
      return publicUrl;
    } on StorageException catch (e) {
      print('❌ StorageService: Storage error - ${e.message}');
      return null;
    } catch (e) {
      print('❌ StorageService: Unexpected error - $e');
      return null;
    }
  }

  /// حذف ملف من Supabase Storage
  /// [fileUrl] - رابط الملف الكامل
  /// يرجع true إذا تم الحذف بنجاح
  Future<bool> deleteImage(String publicId) async {
    try {
      // استخراج مسار الملف من الرابط
      final filePath = extractFilePath(publicId);
      if (filePath == null) {
        print('⚠️ StorageService: Could not extract file path from URL');
        return false;
      }

      await _supabase.storage.from(_bucketName).remove([filePath]);

      print('✅ StorageService: File deleted successfully - $filePath');
      return true;
    } on StorageException catch (e) {
      print('❌ StorageService: Delete error - ${e.message}');
      return false;
    } catch (e) {
      print('❌ StorageService: Unexpected delete error - $e');
      return false;
    }
  }

  /// استخراج مسار الملف من رابط Supabase أو Cloudinary
  /// يرجع المسار داخل الـ bucket أو null
  String? extractFilePath(String url) {
    try {
      // التعامل مع روابط Supabase
      if (url.contains('supabase')) {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;

        // البحث عن 'docs&profiles' في المسار
        final bucketIndex = pathSegments.indexOf('docs%26profiles');
        if (bucketIndex == -1) {
          // محاولة البحث بدون encoding
          final objectIndex = pathSegments.indexOf('object');
          if (objectIndex != -1 && objectIndex + 2 < pathSegments.length) {
            // المسار بعد object/public/bucket_name
            return pathSegments.sublist(objectIndex + 3).join('/');
          }
        } else {
          return pathSegments.sublist(bucketIndex + 1).join('/');
        }
      }

      // التعامل مع روابط Cloudinary القديمة (للتوافق)
      if (url.contains('cloudinary.com')) {
        return _extractCloudinaryPublicId(url);
      }

      return null;
    } catch (e) {
      print('Error extracting file path: $e');
      return null;
    }
  }

  /// استخراج Public ID من رابط Cloudinary (للتوافق مع الصور القديمة)
  String? _extractCloudinaryPublicId(String url) {
    try {
      if (!url.contains('cloudinary.com')) return null;

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= pathSegments.length)
        return null;

      int startIndex = uploadIndex + 1;
      if (pathSegments[startIndex].startsWith('v') &&
          RegExp(r'^v\d+$').hasMatch(pathSegments[startIndex])) {
        startIndex++;
      }

      final publicIdWithExtension = pathSegments.sublist(startIndex).join('/');
      final dotIndex = publicIdWithExtension.lastIndexOf('.');

      if (dotIndex != -1) {
        return publicIdWithExtension.substring(0, dotIndex);
      }

      return publicIdWithExtension;
    } catch (e) {
      print('Error extracting Cloudinary public ID: $e');
      return null;
    }
  }

  /// استخراج معرف الملف من الرابط (للتوافق مع الكود القديم)
  /// هذه الدالة مُحتفظ بها للتوافق مع الكود الموجود
  String? extractPublicId(String url) {
    return extractFilePath(url);
  }
}

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
