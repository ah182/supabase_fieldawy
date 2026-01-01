import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fieldawy_store/core/utils/network_guard.dart';
import 'package:fieldawy_store/features/stories/application/stories_provider.dart';
import 'package:fieldawy_store/features/stories/presentation/widgets/product_selection_dialog.dart'; // Import dialog
import 'package:fieldawy_store/services/story_cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class AddStoryScreen extends ConsumerStatefulWidget {
  const AddStoryScreen({super.key});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final _focusNode = FocusNode(); 
  String? _selectedProductId; // معرف المنتج المختار

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _imageFile = null;
    });

    try {
      final originalFile = File(pickedFile.path);
      final compressedImage = await _compressImage(originalFile);
      final croppedImage = await _cropImage(compressedImage);
      if (croppedImage != null) {
        setState(() {
          _imageFile = croppedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ في معالجة الصورة')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final tempJpegPath = p.join(tempDir.path, 'story_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      tempJpegPath,
      quality: 75,
      minWidth: 1080,
      minHeight: 1920,
      format: CompressFormat.jpeg,
    );
    return compressedFile != null ? File(compressedFile.path) : file;
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'تعديل الصورة',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'تعديل الصورة'),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _saveStory() async {
    if (_imageFile == null) return;
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final imageUrl = await StoryCloudinaryService.uploadStoryImage(_imageFile!.path);
      if (imageUrl == null) throw Exception('Upload failed');

      await NetworkGuard.execute(() async {
        await Supabase.instance.client.from('distributor_stories').insert({
          'distributor_id': user.id,
          'image_url': imageUrl,
          'caption': _captionController.text.trim().isNotEmpty ? _captionController.text.trim() : null,
          'product_link_id': _selectedProductId, // إضافة رابط المنتج
        });
      });

      if (mounted) {
        ref.invalidate(storiesProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 تم نشر الاستوري بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل النشر، يرجى المحاولة لاحقاً')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  // دالة فتح ديالوج اختيار المنتج
  Future<void> _selectProduct() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const ProductSelectionDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedProductId = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // 1. منطقة عرض الصورة
          Positioned.fill(
            child: GestureDetector(
              onTap: _imageFile == null ? () => _showImageSourceDialog() : () => FocusScope.of(context).unfocus(),
              child: Container(
                color: Colors.black,
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.contain)
                    : _isProcessing
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, size: 80, color: Colors.white24),
                              const SizedBox(height: 20),
                              Text(
                                isAr ? 'اضغط لإضافة استوري جديدة' : 'Tap to add a new story',
                                style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAr ? 'اجذب انتباه العملاء بعروضك المميزة' : 'Attract customers with your stories',
                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                              ),
                            ],
                          ),
              ),
            ),
          ),

          // 2. أدوات التحكم الجانبية
          if (_imageFile != null && !_isSaving)
            Positioned(
              top: 100,
              right: isAr ? 20 : null,
              left: isAr ? null : 20,
              child: Column(
                children: [
                  _buildSideButton(
                    icon: Icons.crop_rotate_rounded,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),

          // 3. منطقة الإدخال والارسال (ثابتة في الأسفل)
          if (_imageFile != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // مؤشر المنتج المختار
                    if (_selectedProductId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Chip(
                          label: Text(isAr ? 'تم ربط منتج' : 'Product Linked', style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.indigo,
                          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                          onDeleted: () => setState(() => _selectedProductId = null),
                          avatar: const Icon(Icons.shopping_bag, color: Colors.white, size: 18),
                        ),
                      ),
                      
                    // حقل النص وزر الربط
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4), 
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8), 
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 120),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8), 
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: SingleChildScrollView(
                                    child: TextField(
                                      key: const ValueKey('story_caption_field_dynamic'),
                                      controller: _captionController,
                                      focusNode: _focusNode,
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, 
                                        fontSize: 15
                                      ),
                                      cursorColor: theme.colorScheme.primary,
                                      decoration: InputDecoration(
                                        hintText: isAr ? 'أضف وصفاً للاستوري...' : 'Add a caption...',
                                        hintStyle: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.4), 
                                          fontSize: 14
                                        ),
                                        prefixIcon: Icon(
                                          Icons.mode_edit_outline_rounded, 
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54, 
                                          size: 20
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      maxLines: 5, 
                                      minLines: 1, 
                                      textInputAction: TextInputAction.newline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // زر ربط المنتج بتصميم عصري
                          GestureDetector(
                            onTap: _selectProduct,
                            child: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _selectedProductId != null 
                                    ? [Colors.indigo, Colors.indigoAccent] 
                                    : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                boxShadow: [
                                  if (_selectedProductId != null)
                                    BoxShadow(
                                      color: Colors.indigo.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart_rounded, 
                                    color: _selectedProductId != null ? Colors.white : Colors.white70,
                                    size: 24,
                                  ),
                                  // النقطة الحمراء لجذب الانتباه (تظهر فقط إذا لم يتم اختيار منتج بعد)
                                  if (_selectedProductId == null)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.redAccent.withOpacity(0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // زر النشر
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveStory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isAr ? 'نشر الاستوري' : 'Post Story',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _showImageSourceDialog() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Wrap(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                title: Text(isAr ? 'استخدام الكاميرا' : 'Use Camera', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                title: Text(isAr ? 'اختيار من المعرض' : 'Pick from Gallery', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}