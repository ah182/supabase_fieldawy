import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/user_repository.dart';
import '../../services/auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fieldawy_store/features/authentication/data/storage_service.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  final String documentUrl;
  final String selectedRole;
  final List<String> governorates;
  final List<String> centers;

  const ProfileCompletionScreen({
    super.key,
    required this.documentUrl,
    required this.selectedRole,
    required this.governorates,
    required this.centers,
  });

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  String? _selectedDistributionMethod;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email ?? '';
    _nameController = TextEditingController(text: userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من رفع الصورة الشخصية (إجباري)
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'alert_title'.tr(),
            message: 'auth.profile.please_select_profile_image'.tr(),
            contentType: ContentType.warning,
          ),
        ),
      );
      return;
    }
    
    // التحقق من اختيار طريقة التوزيع للشركات والموزعين
    if ((widget.selectedRole == 'company' || widget.selectedRole == 'distributor') && 
        _selectedDistributionMethod == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.profile.please_select_distribution'.tr())),
      );
      return;
    }

    _showLoadingDialog();

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _hideLoadingDialog();
      return;
    }

    try {
      // 1. Link Anonymous Account to Phone/Password (using phone as fake email)
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final fakeEmail = "$phone@fieldawy.com"; // Construct fake email

      await ref.read(authServiceProvider).linkIdentity(
        email: fakeEmail, 
        password: password
      );

      String? photoUrl;
      // ... image upload logic ...
      if (_imageFile != null) {
        try {
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            _imageFile!.path,
            targetPath,
            quality: 70,
            minWidth: 1024,
            minHeight: 1024,
          );

          final fileToUpload = compressedFile != null ? File(compressedFile.path) : _imageFile!;
          
          photoUrl = await ref.read(storageServiceProvider).uploadDocument(fileToUpload, 'profile_images');
        } catch (e) {
          debugPrint('Error uploading profile image: $e');
        }
      }

      await ref.read(userRepositoryProvider).completeUserProfile(
            id: user.id,
            role: widget.selectedRole,
            documentUrl: widget.documentUrl,
            displayName: _nameController.text.trim(),
            whatsappNumber: phone,
            governorates: widget.governorates,
            centers: widget.centers,
            distributionMethod: _selectedDistributionMethod,
            photoUrl: photoUrl,
          );

      // Force refresh and wait for updated data to ensure AuthGate sees the correct state
      await ref.refresh(userDataProvider.future);

      _hideLoadingDialog();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        _hideLoadingDialog();
        
        String errorMessage = 'auth.profile.update_failed'.tr();
        if (e.toString().contains('email_exists') || e.toString().contains('already been registered')) {
          errorMessage = 'phone_already_exists'.tr();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'error_title'.tr(),
              message: errorMessage,
              contentType: ContentType.failure,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'auth.profile.complete_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'auth.profile.complete_header'.tr(),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // --- Profile Image Picker ---
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 2,
                        ),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? Icon(
                              Icons.person_outline_rounded,
                              size: 60,
                              color: Colors.grey.shade400,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              /// حقل الاسم
              _buildInputField(
                controller: _nameController,
                label: 'auth.profile.app_name_label'.tr(),
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'auth.profile.enter_name'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              /// حقل الهاتف
              _buildInputField(
                controller: _phoneController,
                label: 'auth.profile.whatsapp_label'.tr(),
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'auth.profile.enter_valid_phone'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              /// حقل كلمة المرور (جديد)
              _buildInputField(
                controller: _passwordController,
                label: 'password'.tr(),
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'password_too_short'.tr(); // Needs translation key
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // إظهار خيارات التوزيع فقط للشركات والموزعين
              if (widget.selectedRole == 'company' || widget.selectedRole == 'distributor') ...[
                 Text(
                  'auth.profile.distribution_method'.tr(),
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: Color.fromARGB(255, 34, 40, 85)
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    _buildDistributionCard(
                      icon: Icons.storefront_outlined,
                      title: 'auth.profile.distribution.direct_distribution'.tr(),
                      value: 'direct_distribution',
                    ),
                    const SizedBox(height: 12),
                    _buildDistributionCard(
                      icon: Icons.delivery_dining_outlined,
                      title: 'auth.profile.distribution.order_delivery'.tr(),
                      value: 'order_delivery',
                    ),
                    const SizedBox(height: 12),
                    _buildDistributionCard(
                      icon: Icons.all_inclusive_outlined,
                      title: 'auth.profile.distribution.both_methods'.tr(),
                      value: 'both',
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ] else 
                const SizedBox(height: 40),

              /// زر الحفظ أو اللودر
              _buildGradientButton(
                        text: 'auth.profile.finish_save'.tr(),
                        onPressed: _submitProfile,
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final bool isSelected = _selectedDistributionMethod == value;
    final Color selectedColor = Colors.blueAccent.shade700;
    final Color unselectedColor = Colors.grey.shade600;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDistributionMethod = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: selectedColor,
              )
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        label: Text(label,
            style: TextStyle(color: const Color.fromARGB(255, 34, 40, 85))),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildGradientButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      height: 55,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}