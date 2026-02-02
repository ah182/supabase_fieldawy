import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// خدمة رفع صور الستوري إلى Supabase Storage
/// Bucket: stories
class StoryCloudinaryService {
  static const String _bucketName = 'stories';

  /// رفع صورة الستوري وإرجاع الرابط العام
  /// [filePath] - مسار الصورة المحلية (مضغوطة مسبقاً من add_story_screen)
  static Future<String?> uploadStoryImage(String filePath) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        print('❌ StoryService: User not authenticated');
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ StoryService: File does not exist');
        return null;
      }

      // قراءة الملف
      final bytes = await file.readAsBytes();

      // إنشاء اسم فريد للملف
      final extension = path.extension(filePath).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'distributor_stories/${userId}_$timestamp${extension.isNotEmpty ? extension : '.jpg'}';

      // تحديد نوع الملف
      String contentType = 'image/jpeg';
      if (extension == '.png') {
        contentType = 'image/png';
      } else if (extension == '.webp') {
        contentType = 'image/webp';
      }

      // رفع الملف إلى Supabase Storage
      await supabase.storage.from(_bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      // الحصول على الرابط العام
      final publicUrl =
          supabase.storage.from(_bucketName).getPublicUrl(fileName);

      print('✅ StoryService: Story image uploaded successfully');
      return publicUrl;
    } on StorageException catch (e) {
      print('❌ StoryService: Storage error - ${e.message}');
      return null;
    } catch (e) {
      print('❌ StoryService: Unexpected error - $e');
      return null;
    }
  }

  /// حذف صورة ستوري من Supabase Storage
  static Future<bool> deleteStoryImage(String imageUrl) async {
    try {
      final supabase = Supabase.instance.client;

      // استخراج مسار الملف من الرابط
      final filePath = _extractFilePath(imageUrl);
      if (filePath == null) {
        print('⚠️ StoryService: Could not extract file path');
        return false;
      }

      await supabase.storage.from(_bucketName).remove([filePath]);

      print('✅ StoryService: Story image deleted successfully');
      return true;
    } on StorageException catch (e) {
      print('❌ StoryService: Delete error - ${e.message}');
      return false;
    } catch (e) {
      print('❌ StoryService: Unexpected delete error - $e');
      return false;
    }
  }

  /// استخراج مسار الملف من رابط Supabase
  static String? _extractFilePath(String url) {
    try {
      if (!url.contains('supabase')) return null;

      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // البحث عن 'stories' في المسار
      final bucketIndex = pathSegments.indexOf('stories');
      if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
        return pathSegments.sublist(bucketIndex + 1).join('/');
      }

      // محاولة بديلة: البحث عن 'object/public'
      final objectIndex = pathSegments.indexOf('object');
      if (objectIndex != -1 && objectIndex + 2 < pathSegments.length) {
        return pathSegments.sublist(objectIndex + 3).join('/');
      }

      return null;
    } catch (e) {
      print('Error extracting file path: $e');
      return null;
    }
  }
}
