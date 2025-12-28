import 'dart:convert';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// خدمة ذكية لفصل المعالجة عن التخزين مع نظام حماية (Failover)
class SmartImageService {
  // 1. حساب المعالجة (Primary - Transformation)
  static const String _transformCloudName = 'djynrtwoq';
  static const String _transformPreset = 'ocr_products';

  // 2. حساب التخزين (Secondary - Storage)
  static const String _storageCloudName = 'ddoxy8nbz';
  static const String _storagePreset = 'removed_ocr';

  /// دالة لضغط الصورة قبل الرفع
  Future<File> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(
        tempDir.path, 
        'smart_comp_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );
      
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
    final transformer = CloudinaryPublic(_transformCloudName, _transformPreset, cache: false);
    final responseA = await transformer.uploadFile(
      CloudinaryFile.fromFile(
        imageFile.path, 
        folder: 'temp_processing', 
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    
    // 2. تعديل الرابط
    String transformedUrl = responseA.secureUrl.replaceFirst(
      '/upload/', 
      '/upload/e_background_removal,f_png,q_auto/' 
    );

    // 3. النقل للتخزين
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_storageCloudName/image/upload');
    final responseB = await http.post(uri, body: {
      'file': transformedUrl,
      'upload_preset': _storagePreset,
      'folder': folder,
    });

    if (responseB.statusCode == 200) {
      final jsonResponse = jsonDecode(responseB.body);
      return jsonResponse['secure_url'];
    } else {
      throw Exception('فشل النقل للحساب الثاني: ${responseB.body}');
    }
  }

  /// الخطة البديلة: الرفع المباشر للتخزين (بدون إزالة خلفية)
  Future<String?> _uploadDirectlyToStorage(File imageFile, String folder) async {
    print('⚠️ (Plan B) الكوتا ممتلئة أو حدث خطأ. جاري الرفع المباشر للتخزين...');
    try {
      final storage = CloudinaryPublic(_storageCloudName, _storagePreset, cache: false);
      final response = await storage.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path, 
          folder: folder, 
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('❌ فشل الرفع المباشر أيضاً: $e');
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
      final directResult = await _uploadDirectlyToStorage(compressedFile, folder);
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