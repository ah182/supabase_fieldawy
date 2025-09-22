import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/user_repository.dart';
import '../../services/auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

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
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;


    _showLoadingDialog();

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _hideLoadingDialog();
      return;
    }

    try {
      await ref.read(userRepositoryProvider).completeUserProfile(
            id: user.id,
            role: widget.selectedRole,
            documentUrl: widget.documentUrl,
            displayName: _nameController.text.trim(),
            whatsappNumber: _phoneController.text.trim(),
            governorates: widget.governorates,
            centers: widget.centers,
          );

      ref.invalidate(userDataProvider);

      _hideLoadingDialog();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DrawerWrapper()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        _hideLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'خطأ'.tr(),
              message: '${'profileUpdateFailed'.tr()}: $e',
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
          'completeProfile'.tr(),
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
                'Complete your profile'.tr(),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 75
              ),

              /// حقل الاسم
              _buildInputField(
                controller: _nameController,
                label: 'appNameLabel'.tr(),
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'pleaseEnterName'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              /// حقل الهاتف
              _buildInputField(
                controller: _phoneController,
                label: 'whatsappNumberLabel'.tr(),
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'pleaseEnterValidPhone'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              /// زر الحفظ أو اللودر
              _buildGradientButton(
                        text: 'finishAndSave'.tr(),
                        onPressed: _submitProfile,
                      ),
            ],
          ),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        label: Text(label, style: TextStyle(color: const Color.fromARGB(255, 34, 40, 85))),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
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
