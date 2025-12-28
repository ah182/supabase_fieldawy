import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/data/vet_supplies_repository.dart';
// ignore: unused_import
import 'package:fieldawy_store/services/cloudinary_service.dart';
import 'package:fieldawy_store/services/smart_image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// ignore: unused_import
import 'package:http/http.dart' as http;

class AddVetSupplyScreen extends ConsumerStatefulWidget {
  const AddVetSupplyScreen({super.key});

  @override
  ConsumerState<AddVetSupplyScreen> createState() => _AddVetSupplyScreenState();
}

class _AddVetSupplyScreenState extends ConsumerState<AddVetSupplyScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes;
  File? _processedImageFile;
  bool _isProcessing = false;
  bool _isSaving = false;

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _packageController = TextEditingController();
  final _phoneController = TextEditingController();
  String _completePhoneNumber = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _packageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _processedImageBytes = null;
      _originalImage = null;
      _processedImageFile = null;
    });

    try {
      _originalImage = File(pickedFile.path);

      // 1. Compress
      final compressedImage = await _compressImage(_originalImage!);

      // 2. Crop
      final croppedImage = await _cropImage(compressedImage);
      if (croppedImage == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Remove Background
      final bgRemovedBytes = await _removeBackground(croppedImage);
      if (bgRemovedBytes == null) {
        throw Exception('Background removal failed.');
      }

      // Save processed image
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'processed_supply_${DateTime.now().millisecondsSinceEpoch}.png');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bgRemovedBytes);

      setState(() {
        _processedImageBytes = bgRemovedBytes;
        _processedImageFile = tempFile;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('vet_supplies_feature.messages.process_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final tempJpegPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_temp.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      tempJpegPath,
      quality: 80,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
    );
    return compressedFile != null ? File(compressedFile.path) : file;
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'vet_supplies_feature.fields.crop_image_title'.tr(),
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'vet_supplies_feature.fields.crop_image_title'.tr(),
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<Uint8List?> _removeBackground(File imageFile) async {
    // 💡 Fallback: Return original image bytes to avoid broken API
    print('ℹ️ Background removal skipped for stability. Using cropped image.');
    return await imageFile.readAsBytes();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSupply() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_processedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('vet_supplies_feature.messages.select_image'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image using Smart Service (Optimized for Quota)
      // Account A -> Remove BG -> Account B -> Save
      final smartImageService = ref.read(smartImageServiceProvider);
      final finalUrl = await smartImageService.processAndSaveImage(
        imageFile: _processedImageFile!,
        folder: 'vet_supplies',
      );

      if (finalUrl == null) {
        throw Exception('vet_supplies_feature.messages.upload_error'.tr());
      }

      // Create supply
      final repository = ref.read(vetSuppliesRepositoryProvider);
      final price = double.parse(_priceController.text);

      await repository.createVetSupply(
        name: _nameController.text,
        description: _descriptionController.text,
        price: price,
        imageUrl: finalUrl,
        phone: _completePhoneNumber,
        package: _packageController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('vet_supplies_feature.messages.add_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('vet_supplies_feature.messages.save_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('vet_supplies_feature.add_title'.tr()),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Image Section
            GestureDetector(
              onTap: _isProcessing ? null : _showImageSourceDialog,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _isProcessing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text('vet_supplies_feature.messages.processing_image'.tr()),
                          ],
                        ),
                      )
                    : _processedImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _processedImageBytes!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 8),
                              Text(
                                'vet_supplies_feature.actions.tap_to_pick_image'.tr(),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
              ),
            ),
            if (_processedImageBytes != null && !_isProcessing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.edit),
                label: Text('vet_supplies_feature.actions.change_image'.tr()),
              ),
            ],
            const SizedBox(height: 24),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'vet_supplies_feature.fields.name_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'vet_supplies_feature.fields.name_required'.tr();
                }
                if (value.length < 3) {
                  return 'vet_supplies_feature.fields.name_too_short'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price Field
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'vet_supplies_feature.fields.price_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'vet_supplies_feature.fields.price_required'.tr();
                }
                final price = double.tryParse(value);
                if (price == null || price < 0) {
                  return 'vet_supplies_feature.fields.price_invalid'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Package Field
            TextFormField(
              controller: _packageController,
              decoration: InputDecoration(
                labelText: 'vet_supplies_feature.fields.package_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'vet_supplies_feature.fields.package_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'vet_supplies_feature.fields.description_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'vet_supplies_feature.fields.description_required'.tr();
                }
                if (value.length < 10) {
                  return 'vet_supplies_feature.fields.description_too_short'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Field
            IntlPhoneField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'vet_supplies_feature.fields.phone_label'.tr(),
                border: const OutlineInputBorder(),
              ),
              initialCountryCode: 'EG',
              disableLengthCheck: true,
              onChanged: (phone) {
                _completePhoneNumber = phone.completeNumber;
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'vet_supplies_feature.fields.phone_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSupply,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'vet_supplies_feature.actions.save'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
