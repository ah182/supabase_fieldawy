import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نتيجة رفع مؤقت
class TempUploadResult {
  final String secureUrl;
  final String publicId;
  const TempUploadResult({required this.secureUrl, required this.publicId});
}

/// كاش محلي للصور المؤقتة
class TempImageCache {
  static const _key = 'temp_images';

  /// حفظ publicId جديد
  static Future<void> addTempImage(String publicId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    list.add(publicId);
    await prefs.setStringList(_key, list);
  }

  /// قراءة كل الصور المؤقتة
  static Future<List<String>> getTempImages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// حذف publicId واحد من التخزين
  static Future<void> removeTempImage(String publicId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    list.remove(publicId);
    await prefs.setStringList(_key, list);
  }
}

class StorageService {
  static const _cloudName = 'dk8twnfrk';
  static const _apiKey = '554622557218694';
  static const _apiSecret = 'vFNW9PX3Rt-4ARIBFPnO4qqhV9I';

  final CloudinaryPublic _cloudinaryFinal = CloudinaryPublic(
    _cloudName,
    'background_removal',
    cache: false,
  );

  /// رفع الصورة مؤقتًا Signed + Auto-delete بعد دقيقة
  Future<TempUploadResult?> uploadTempImage(File image) async {
    try {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final folder = 'temp';
      final paramsToSign = 'folder=$folder&timestamp=$timestamp$_apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['folder'] = folder
        ..fields['timestamp'] = timestamp
        ..fields['api_key'] = _apiKey
        ..fields['signature'] = signature
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(respStr);

        final result = TempUploadResult(
          secureUrl: jsonResp['secure_url'],
          publicId: jsonResp['public_id'],
        );

        // حفظ الصورة مؤقتًا في الكاش
        await TempImageCache.addTempImage(result.publicId);

        // حذف الصورة بعد دقيقة واحدة (background task)
        Future.delayed(const Duration(minutes: 1), () {
          deleteTempImage(result.publicId);
        });

        return result;
      } else {
        print('Temp upload failed: $respStr');
        return null;
      }
    } catch (e) {
      print('❌ Temp upload error: $e');
      return null;
    }
  }

  /// رفع الصورة نهائيًا مع transformations
  Future<String?> uploadFinalImage(
    File image, {
    String transformation = 'c_fill,g_auto,h_720,w_1280,e_background_removal,f_png,q_auto',
  }) async {
    try {
      final resp = await _cloudinaryFinal.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      const marker = '/upload/';
      final i = resp.secureUrl.indexOf(marker);
      if (i != -1) {
        return resp.secureUrl.replaceFirst(marker, '$marker$transformation/');
      }
      return resp.secureUrl;
    } catch (e) {
      print('❌ Final upload error: $e');
      return null;
    }
  }

  /// بناء رابط Preview معدل
  String buildPreviewUrl(String secureUrl,
      {String transformation = 'c_fill,g_auto,h_720,w_1280,e_background_removal,f_png,q_auto'}) {
    const marker = '/upload/';
    final i = secureUrl.indexOf(marker);
    if (i == -1) return secureUrl;
    return secureUrl.replaceFirst(marker, '$marker$transformation/');
  }

  /// رفع مستند في فولدر محدد
  Future<String?> uploadDocument(File image, String folderName) async {
    try {
      final response = await _cloudinaryFinal.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folderName,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print('Error uploading document to Cloudinary: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error uploading document: $e');
      return null;
    }
  }

  /// حذف الصورة المؤقتة عن طريق publicId
  Future<bool> deleteTempImage(String publicId) async {
    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/resources/image/upload?public_ids[]=$publicId');
      final response = await http.delete(
        url,
        headers: {
          'Authorization':
              'Basic ' + base64Encode(utf8.encode('$_apiKey:$_apiSecret')),
        },
      );

      if (response.statusCode == 200) {
        print('✅ Temp image deleted successfully');
        await TempImageCache.removeTempImage(publicId);
        return true;
      }

      print('Delete failed: ${response.body}');
      return false;
    } catch (e) {
      print('Error deleting temp image: $e');
      return false;
    }
  }

  /// مسح كل الصور المؤقتة من الكاش (عند بداية تشغيل التطبيق)
  Future<void> cleanupTempImages() async {
    final tempImages = await TempImageCache.getTempImages();
    for (final id in tempImages) {
      await deleteTempImage(id);
    }
  }
}

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
