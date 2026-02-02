import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة ذكية لفصل المعالجة عن التخزين مع نظام حماية (Failover)
class SmartImageService {
  // 1. حساب المعالجة (Primary - Transformation)
  static const String _transformCloudName = 'dj8zviywh';
  static const String _transformPreset = 'ocr_products';

  // 2. حساب التخزين (تم استبداله بـ Supabase Storage)
  static const String _bucketName = 'ocr';

  /// دالة لضغط الصورة قبل الرفع
  Future<File> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path,
          'smart_comp_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        tempPath,
        quality: 70,
        minWidth: 1000,
        minHeight: 1000,
        format: CompressFormat.jpeg,
      );

      return compressedFile != null ? File(compressedFile.path) : file;
    } catch (e) {
      print('⚠️ فشل الضغط، سيتم استخدام الأصل: $e');
      return file;
    }
  }

  /// المحاولة الأساسية: رفع للمعالج -> إزالة خلفية -> نقل للتخزين
  Future<String> _processViaTransformer(File imageFile, String folder) async {
    print('🔄 (Plan A) محاولة إزالة الخلفية...');

    // 1. الرفع للمعالج
    final transformer =
        CloudinaryPublic(_transformCloudName, _transformPreset, cache: false);
    final responseA = await transformer.uploadFile(
      CloudinaryFile.fromFile(
        imageFile.path,
        folder: 'temp_processing',
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    // 2. تعديل الرابط
    String transformedUrl = responseA.secureUrl
        .replaceFirst('/upload/', '/upload/e_background_removal,f_png,q_auto/');

    // 3. النقل للتخزين (Supabase)
    print('📥 جاري تنزيل الصورة المعالجة...');
    final imageResponse = await http.get(Uri.parse(transformedUrl));

    if (imageResponse.statusCode != 200) {
      throw Exception('فشل تنزيل الصورة المعالجة: ${imageResponse.statusCode}');
    }

    // 4. الرفع إلى Supabase
    final filename = '${DateTime.now().millisecondsSinceEpoch}_processed.png';
    final path = '$folder/$filename';

    print('📤 جاري الرفع إلى Supabase (Bucket: $_bucketName, Path: $path)...');

    await Supabase.instance.client.storage.from(_bucketName).uploadBinary(
          path,
          imageResponse.bodyBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    final publicUrl =
        Supabase.instance.client.storage.from(_bucketName).getPublicUrl(path);

    return publicUrl;
  }

  /// رفع مباشر للتخزين (بدون معالجة) - يستخدم للكتب والكورسات
  Future<String?> uploadDirectly(File imageFile, String folder) async {
    return _uploadDirectlyToStorage(imageFile, folder);
  }

  /// الخطة البديلة: الرفع المباشر للتخزين (بدون إزالة خلفية)
  Future<String?> _uploadDirectlyToStorage(
      File imageFile, String folder) async {
    print(
        '⚠️ (Plan B) الكوتا ممتلئة أو حدث خطأ. جاري الرفع المباشر لـ Supabase...');
    try {
      final extension = p.extension(imageFile.path).replaceAll('.', '');
      final filename = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$folder/$filename';

      await Supabase.instance.client.storage.from(_bucketName).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          Supabase.instance.client.storage.from(_bucketName).getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print('❌ فشل الرفع المباشر لـ Supabase: $e');
      return null;
    }
  }

  /// الدالة الرئيسية التي تدير العملية
  Future<String?> processAndSaveImage({
    required File imageFile,
    required String folder,
  }) async {
    File compressedFile = await _compressImage(imageFile);

    try {
      // محاولة الخطة (أ): إزالة الخلفية
      final result = await _processViaTransformer(compressedFile, folder);
      print('✅ تمت العملية بنجاح (مع إزالة الخلفية)');
      return result;
    } catch (e) {
      // في حالة حدوث أي خطأ (كوتا، انترنت ضعيف، خطأ سيرفر)
      print('❗ تعذرت المعالجة (السبب: $e)');

      // الانتقال للخطة (ب): الرفع المباشر
      final directResult =
          await _uploadDirectlyToStorage(compressedFile, folder);
      if (directResult != null) {
        print('✅ تم حفظ الصورة الأصلية بنجاح في حساب التخزين');
      }
      return directResult;
    } finally {
      // تنظيف الملفات المؤقتة
      if (compressedFile.path != imageFile.path) {
        try {
          if (await compressedFile.exists()) {
            await compressedFile.delete();
          }
        } catch (e) {
          print('⚠️ فشل حذف الملف المؤقت: $e');
        }
      }
    }
  }
}

final smartImageServiceProvider = Provider<SmartImageService>((ref) {
  return SmartImageService();
});
