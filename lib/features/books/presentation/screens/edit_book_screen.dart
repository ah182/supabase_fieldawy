import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/services/smart_image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cached_network_image/cached_network_image.dart';

class EditBookScreen extends ConsumerStatefulWidget {
  final dynamic book;

  const EditBookScreen({super.key, required this.book});

  @override
  ConsumerState<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends ConsumerState<EditBookScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes;
  File? _processedImageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _imageChanged = false;

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bookNameController;
  late final TextEditingController _authorController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _phoneController;
  late String _completePhoneNumber;
  late String _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _bookNameController = TextEditingController(text: widget.book.name);
    _authorController = TextEditingController(text: widget.book.author);
    _descriptionController =
        TextEditingController(text: widget.book.description);
    _priceController =
        TextEditingController(text: widget.book.price.toString());
    _phoneController = TextEditingController();
    _completePhoneNumber = widget.book.phone;
    _currentImageUrl = widget.book.imageUrl;
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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

      // 3. Read final image bytes
      final imageBytes = await croppedImage.readAsBytes();

      setState(() {
        _processedImageBytes = imageBytes;
        _processedImageFile = croppedImage;
        _imageChanged = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل معالجة الصورة: $e'),
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
    final tempJpegPath = p.join(
        tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_temp.jpg');
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
          toolbarTitle: 'Crop Book Cover',
          toolbarColor: Colors.orange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Book Cover',
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      String imageUrl = _currentImageUrl;

      // 1. Upload new image if changed
      if (_imageChanged && _processedImageFile != null) {
        final smartImageService = ref.read(smartImageServiceProvider);
        final uploadedUrl = await smartImageService.uploadDirectly(
          _processedImageFile!,
          'vet_books',
        );

        if (uploadedUrl == null) {
          throw Exception('profile_feature.image_upload_failed'.tr());
        }
        imageUrl = uploadedUrl;
      }

      // Clean and validate phone number format (E.164)
      final cleanPhone = _completePhoneNumber.replaceAll(RegExp(r'[^+\d]'), '');

      if (cleanPhone.isEmpty || !cleanPhone.startsWith('+')) {
        throw Exception('job_offers_feature.phone_invalid'.tr());
      }

      // Validate E.164 format: +[1-9]\d{1,14}
      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(cleanPhone)) {
        throw Exception('job_offers_feature.phone_invalid'.tr());
      }

      // 2. Update book data in Supabase
      final success =
          await ref.read(myBooksNotifierProvider.notifier).updateBook(
                bookId: widget.book.id,
                name: _bookNameController.text.trim(),
                author: _authorController.text.trim(),
                description: _descriptionController.text.trim(),
                price: double.parse(_priceController.text),
                phone: cleanPhone,
                imageUrl: imageUrl,
              );

      if (mounted) {
        setState(() => _isSaving = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('books_feature.update_success'.tr()),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pop(true);
        } else {
          throw Exception('books_feature.update_failed_message'.tr());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('books_feature.error_occurred'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('books_feature.edit'.tr()),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Book Cover Image
            GestureDetector(
              onTap: _isProcessing ? null : _showImageSourceDialog,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isProcessing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'books_feature.processing_image'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
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
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: _currentImageUrl,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.orange[100],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.orange[100],
                                    child: const Icon(
                                      Icons.menu_book_rounded,
                                      color: Colors.orange,
                                      size: 60,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.edit,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'books_feature.tap_to_change_image'
                                                .tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),

            // Book Name
            TextFormField(
              controller: _bookNameController,
              decoration: InputDecoration(
                labelText: 'books_feature.name_label'.tr(),
                prefixIcon: const Icon(Icons.book),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'books_feature.name_required'.tr();
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 20),

            // Author Name
            TextFormField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: 'books_feature.author_label'.tr(),
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'books_feature.author_required'.tr();
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 20),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'books_feature.description_label'.tr(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.description),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'books_feature.description_required'.tr();
                }
                if (value.trim().length < 20) {
                  return 'books_feature.description_too_short'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Price
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'books_feature.price_label'.tr(),
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: 'products.currency'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'books_feature.price_required'.tr();
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'products.invalid_price'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Phone Number
            IntlPhoneField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'phoneNumber'.tr(),
                hintText: 'books_feature.phone_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              initialCountryCode: 'EG',
              languageCode: context.locale.languageCode,
              disableLengthCheck: true,
              initialValue: _completePhoneNumber.replaceFirst('+', ''),
              onChanged: (phone) {
                setState(() {
                  _completePhoneNumber = phone.completeNumber;
                });
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'phoneNumberRequired'.tr();
                }
                _completePhoneNumber = phone.completeNumber;
                return null;
              },
              invalidNumberMessage: 'phoneNumberInvalid'.tr(),
              dropdownIconPosition: IconPosition.trailing,
              showCountryFlag: true,
              showDropdownIcon: true,
              flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveBook,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'books_feature.saving'.tr()
                      : 'books_feature.save_changes'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
