import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class StorageService {
  static const _cloudName = 'dk8twnfrk';
  static const _apiKey = '554622557218694';
  static const _apiSecret = 'vFNW9PX3Rt-4ARIBFPnO4qqhV9I';

  final CloudinaryPublic _cloudinaryDocuments = CloudinaryPublic(
    _cloudName,
    'fieldawy_unsigned_temp',
    cache: false,
  );

  /// رفع مستند في فولدر محدد
  Future<String?> uploadDocument(File image, String folderName) async {
    try {
      final response = await _cloudinaryDocuments.uploadFile(
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

  /// حذف صورة من Cloudinary باستخدام Signed API
  Future<bool> deleteImage(String publicId) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      
      // التوقيع مطلوب لعملية الحذف
      final paramsToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy');

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'timestamp': timestamp,
          'api_key': _apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['result'] == 'ok') {
          print('✅ Image deleted successfully: $publicId');
          return true;
        }
      }
      
      print('❌ Failed to delete image. Code: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// استخراج Public ID من رابط الصورة
  String? extractPublicId(String url) {
    try {
      // نتأكد أن الرابط من كلاوديناري
      if (!url.contains('cloudinary.com')) return null;

      // مثال للرابط:
      // https://res.cloudinary.com/dk8twnfrk/image/upload/v1733311111/profile_images/abc123_xyz.jpg
      
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // عادة الـ Public ID يبدأ بعد 'upload' و الـ version (v12345...)
      // pathSegments قد تكون: [dk8twnfrk, image, upload, v1733..., profile_images, abc.jpg]
      
      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= pathSegments.length) return null;

      // نتخطى 'upload' وأي جزء يبدأ بـ 'v' وأرقام (version)
      int startIndex = uploadIndex + 1;
      if (pathSegments[startIndex].startsWith('v') && 
          RegExp(r'^v\d+$').hasMatch(pathSegments[startIndex])) {
        startIndex++;
      }

      // نجمع الباقي ونحذف الامتداد
      final publicIdWithExtension = pathSegments.sublist(startIndex).join('/');
      final dotIndex = publicIdWithExtension.lastIndexOf('.');
      
      if (dotIndex != -1) {
        return publicIdWithExtension.substring(0, dotIndex);
      }
      
      return publicIdWithExtension;
    } catch (e) {
      print('Error extracting public ID: $e');
      return null;
    }
  }
}

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());