import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service class for handling Cloudinary uploads using the main account.
class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  /// Default configuration
  CloudinaryService()
      : _cloudinary = CloudinaryPublic(
          'djynrtwoq',
          'ocr_products',
          cache: false,
        );

  /// Uploads an image file to a specified folder in Cloudinary.
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