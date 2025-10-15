import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:fieldawy_store/services/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class EditVetSupplyScreen extends ConsumerStatefulWidget {
  final VetSupply supply;

  const EditVetSupplyScreen({super.key, required this.supply});

  @override
  ConsumerState<EditVetSupplyScreen> createState() => _EditVetSupplyScreenState();
}

class _EditVetSupplyScreenState extends ConsumerState<EditVetSupplyScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes;
  File? _processedImageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _imageChanged = false;

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _phoneController;
  String _completePhoneNumber = '';
  String _currentImageUrl = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supply.name);
    _descriptionController = TextEditingController(text: widget.supply.description);
    _priceController = TextEditingController(text: widget.supply.price.toString());
    
    // Extract phone number without country code for display
    final phone = widget.supply.phone;
    _phoneController = TextEditingController(
      text: phone.startsWith('+20') ? phone.substring(3) : phone,
    );
    _completePhoneNumber = widget.supply.phone;
    _currentImageUrl = widget.supply.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          toolbarTitle: 'قص صورة المستلزم',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'قص صورة المستلزم',
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<Uint8List?> _removeBackground(File imageFile) async {
    try {
      final url = Uri.parse('https://ah3181997-my-rembg-space.hf.space/api/remove');
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        return await response.stream.toBytes();
      } else {
        throw Exception('Failed to remove background: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove background: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('الكاميرا'),
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

  Future<void> _updateSupply() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      String imageUrl = _currentImageUrl;

      // Upload new image if changed
      if (_imageChanged && _processedImageFile != null) {
        final cloudinaryService = ref.read(cloudinaryServiceProvider);
        final uploadedUrl = await cloudinaryService.uploadImage(
          imageFile: _processedImageFile!,
          folder: 'vet_supplies',
        );
        
        if (uploadedUrl == null) {
          throw Exception('فشل رفع الصورة');
        }
        
        imageUrl = uploadedUrl;
      }

      // Update supply
      final repository = ref.read(vetSuppliesRepositoryProvider);
      final price = double.parse(_priceController.text);

      await repository.updateVetSupply(
        id: widget.supply.id,
        name: _nameController.text,
        description: _descriptionController.text,
        price: price,
        imageUrl: imageUrl,
        phone: _completePhoneNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المستلزم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحديث: $e'),
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
        title: const Text('تعديل المستلزم'),
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('جاري معالجة الصورة...'),
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
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: _currentImageUrl,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                                Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit,
                                            size: 48, color: Colors.white),
                                        const SizedBox(height: 8),
                                        Text(
                                          'اضغط لتغيير الصورة',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستلزم *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال اسم المستلزم';
                }
                if (value.length < 3) {
                  return 'يجب أن يكون الاسم 3 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price Field
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'السعر (جنيه) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال السعر';
                }
                final price = double.tryParse(value);
                if (price == null || price < 0) {
                  return 'السعر غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال وصف المستلزم';
                }
                if (value.length < 10) {
                  return 'يجب أن يكون الوصف 10 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Field
            IntlPhoneField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف *',
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'EG',
              onChanged: (phone) {
                _completePhoneNumber = phone.completeNumber;
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'الرجاء إدخال رقم الهاتف';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Update Button
            ElevatedButton(
              onPressed: _isSaving ? null : _updateSupply,
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
                  : const Text(
                      'حفظ التعديلات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
