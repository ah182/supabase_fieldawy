import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ImageCropperTestScreen extends StatefulWidget {
  const ImageCropperTestScreen({super.key});

  @override
  State<ImageCropperTestScreen> createState() => _ImageCropperTestScreenState();
}

class _ImageCropperTestScreenState extends State<ImageCropperTestScreen> {
  // ignore: unused_field
  File? _croppedImage;
  Uint8List? _processedImage;
  bool _isLoading = false;

  /// 🟢 دالة ترفع الصورة إلى السيرفر وتستقبل النتيجة بدون الخلفية
  Future<void> _removeBackground(File imageFile) async {
    try {
      setState(() => _isLoading = true);

      final url =
          Uri.parse("https://ah3181997-my-rembg-space.hf.space/api/remove");

      final request = http.MultipartRequest('POST', url);
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final resultBytes = await response.stream.toBytes();
        setState(() {
          _processedImage = resultBytes;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('image_cropper_feature.http_error'.tr(namedArgs: {'statusCode': response.statusCode.toString()}))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('image_cropper_feature.processing_failed'.tr())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🟢 اختيار + قص الصورة
  Future<void> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _croppedImage = File(croppedFile.path);
          _processedImage = null; // مسح النتيجة القديمة لو فيه
        });

        // 🟢 بعد القص ارفع الصورة للسيرفر مباشرة
        await _removeBackground(File(croppedFile.path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove Background Test'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _processedImage != null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: 200, // Set a fixed width similar to ProductCard
                      height: 300, // Set a fixed height similar to ProductCard
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 3,
                        shadowColor:
                            Theme.of(context).shadowColor.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            Expanded(
                              flex: 4,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.3),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                child: Image.memory(_processedImage!,
                                    fit: BoxFit.contain),
                              ),
                            ),
                            // Product Info
                            Flexible(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Product Name
                                    Text(
                                      'منتج افتراضي',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    // Price
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '100 ج.م',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Distributor Name
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.store_outlined,
                                          size: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: Text(
                                            'موزع افتراضي',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                  fontSize: 9,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Text('No image selected.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndCropImage,
        tooltip: 'Pick Image',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
