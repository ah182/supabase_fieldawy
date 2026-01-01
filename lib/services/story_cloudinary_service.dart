import 'package:cloudinary_public/cloudinary_public.dart';

/// خدمة مخصصة لرفع صور الستوري على حساب Cloudinary المستقل
class StoryCloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dj8zviywh',
    'dis_stories',
    cache: false,
  );

  /// رفع صورة الستوري وإرجاع الرابط
  static Future<String?> uploadStoryImage(String filePath) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: CloudinaryResourceType.Image,
          folder: 'distributor_stories',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('❌ StoryCloudinaryService Error: $e');
      return null;
    }
  }
}
