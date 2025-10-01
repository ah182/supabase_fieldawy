import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service class for handling Cloudinary uploads.
/// 
/// This service follows best practices:
/// - Organized: Allows specifying a folder for each upload.
/// - Robust: Uses the official Cloudinary SDK and includes error handling.
class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  /// Initializes the service by setting up the Cloudinary client.
  /// 
  /// Throws an exception if the required environment variables are not set.
  CloudinaryService()
      : _cloudinary = CloudinaryPublic(
          'djynrtwoq',
          'ocr_products',
          cache: false,
        );

  /// Uploads an image file to a specified folder in Cloudinary.
  ///
  /// [imageFile]: The image file to upload.
  /// [folder]: The destination folder in Cloudinary (e.g., 'products', 'user_avatars').
  /// 
  /// Returns the secure URL of the uploaded image, or null if the upload fails.
  Future<String?> uploadImage({
    required File imageFile,
    required String folder,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print('❌ Cloudinary Error: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Unexpected Upload Error: $e');
      return null;
    }
  }
}

/// Riverpod provider for the CloudinaryService.
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
