import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fieldawy_store/features/posts/application/posts_provider.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:fieldawy_store/features/posts/domain/post_model.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final PostModel? postToEdit;
  const CreatePostScreen({super.key, this.postToEdit});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _maxLength = 500;
  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _removeExistingImage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      _contentController.text = widget.postToEdit!.content;
      _existingImageUrl = widget.postToEdit!.imageUrl;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(userDataProvider).valueOrNull;
    final charCount = _contentController.text.length;
    final isValid = charCount > 0 && charCount <= _maxLength;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: CachedNetworkImage(
            imageUrl:
                "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Xmark-icon.png",
            width: 24,
            height: 24,
            color: Theme.of(context).iconTheme.color,
            placeholder: (context, url) => const FaIcon(FontAwesomeIcons.xmark),
            errorWidget: (context, url, error) =>
                const FaIcon(FontAwesomeIcons.xmark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.postToEdit != null
            ? (context.locale.languageCode == 'ar'
                ? 'تعديل المنشور'
                : 'Edit Post')
            : (context.locale.languageCode == 'ar'
                ? 'منشور جديد'
                : 'New Post')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPublishButton(theme, isValid),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info header
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: currentUser?.photoUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: currentUser!.photoUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(
                            (currentUser?.displayName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.displayName ?? 'المستخدم',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CachedNetworkImage(
                            imageUrl:
                                "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Earth-Americas-icon.png",
                            width: 12,
                            height: 12,
                            color: Colors.blue,
                            placeholder: (context, url) => const FaIcon(
                                FontAwesomeIcons.earthAmericas,
                                size: 12,
                                color: Colors.blue),
                            errorWidget: (context, url, error) => const FaIcon(
                                FontAwesomeIcons.earthAmericas,
                                size: 12,
                                color: Colors.blue),
                          ),
                          SizedBox(width: 4),
                          Text(
                            context.locale.languageCode == 'ar'
                                ? 'عام'
                                : 'Public',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Content input
            TextField(
              controller: _contentController,
              maxLength: _maxLength,
              maxLines: null,
              minLines: 5,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxLength),
              ],
              decoration: InputDecoration(
                hintText: context.locale.languageCode == 'ar'
                    ? 'ماذا يدور في ذهنك؟'
                    : "What's on your mind?",
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                ),
                border: InputBorder.none,
                counterStyle: TextStyle(
                  color: charCount > _maxLength * 0.9
                      ? Colors.orange
                      : Colors.grey,
                ),
              ),
              style: const TextStyle(fontSize: 18),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Image preview
            if (_selectedImage != null ||
                (_existingImageUrl != null && !_removeExistingImage))
              _buildImagePreview(isDark),

            const SizedBox(height: 16),

            // Add image button
            _buildAddImageButton(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton(ThemeData theme, bool isValid) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isValid && !_isSubmitting
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              )
            : null,
        color: !isValid || _isSubmitting ? Colors.grey[300] : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isValid && !_isSubmitting ? _submitPost : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.postToEdit != null
                        ? (context.locale.languageCode == 'ar' ? 'حفظ' : 'Save')
                        : (context.locale.languageCode == 'ar'
                            ? 'نشر'
                            : 'Post'),
                    style: TextStyle(
                      color: isValid ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool isDark) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _selectedImage != null
                ? Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.contain,
                  )
                : CachedNetworkImage(
                    imageUrl: _existingImageUrl!,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedImage != null) {
                  _selectedImage = null;
                } else {
                  _removeExistingImage = true;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Xmark-icon.png",
                width: 20,
                height: 20,
                color: Colors.white,
                placeholder: (context, url) => const FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 20,
                ),
                errorWidget: (context, url, error) => const FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Image-icon.png",
                width: 22,
                height: 22,
                color: Colors.green,
                placeholder: (context, url) => const FaIcon(
                    FontAwesomeIcons.image,
                    color: Colors.green,
                    size: 22),
                errorWidget: (context, url, error) => const FaIcon(
                    FontAwesomeIcons.image,
                    color: Colors.green,
                    size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _selectedImage == null
                  ? (context.locale.languageCode == 'ar'
                      ? 'إضافة صورة'
                      : 'Add Image')
                  : (context.locale.languageCode == 'ar'
                      ? 'تغيير الصورة'
                      : 'Change Image'),
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    // Show bottom sheet to choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Images-icon.png",
                width: 24,
                height: 24,
                color: Theme.of(context).iconTheme.color,
                placeholder: (context, url) =>
                    const FaIcon(FontAwesomeIcons.images),
                errorWidget: (context, url, error) =>
                    const FaIcon(FontAwesomeIcons.images),
              ),
              title: Text(context.locale.languageCode == 'ar'
                  ? 'اختيار من المعرض'
                  : 'Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Camera-icon.png",
                width: 24,
                height: 24,
                color: Theme.of(context).iconTheme.color,
                placeholder: (context, url) =>
                    const FaIcon(FontAwesomeIcons.camera),
                errorWidget: (context, url, error) =>
                    const FaIcon(FontAwesomeIcons.camera),
              ),
              title: Text(context.locale.languageCode == 'ar'
                  ? 'التقاط صورة'
                  : 'Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
        // Use Photo Picker (no permissions required on Android 13+)
        requestFullMetadata: false,
      );

      if (image != null) {
        setState(() => _selectedImage = image);
      }
    }
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    bool success;
    if (widget.postToEdit != null) {
      success = await ref.read(postsProvider.notifier).updatePost(
            postId: widget.postToEdit!.id,
            content: content,
            image: _selectedImage,
            removeImage: _removeExistingImage,
          );
    } else {
      success = await ref.read(postsProvider.notifier).createPost(
            content: content,
            image: _selectedImage,
          );
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.postToEdit != null
                  ? (context.locale.languageCode == 'ar'
                      ? 'تم تعديل المنشور بنجاح! ✅'
                      : 'Post updated successfully! ✅')
                  : (context.locale.languageCode == 'ar'
                      ? 'تم نشر المنشور بنجاح! 🎉'
                      : 'Post published successfully! 🎉'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.locale.languageCode == 'ar'
                ? 'حدث خطأ أثناء النشر'
                : 'Error publishing post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
