import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
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
  String? _selectedDistributionMethod;

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
      await ref.read(userRepositoryProvider).completeUserProfile(
            id: user.id,
            role: widget.selectedRole,
            documentUrl: widget.documentUrl,
            displayName: _nameController.text.trim(),
            whatsappNumber: _phoneController.text.trim(),
            governorates: widget.governorates,
            centers: widget.centers,
            distributionMethod: _selectedDistributionMethod,
          );

      ref.invalidate(userDataProvider);

      _hideLoadingDialog();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
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
              message: '${'auth.profile.update_failed'.tr()}: $e',
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
              const SizedBox(height: 75
              ),

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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        label: Text(label,
            style: TextStyle(color: const Color.fromARGB(255, 34, 40, 85))),
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
