import 'package:easy_localization/easy_localization.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../widgets/shimmer_loader.dart';
import '../../data/user_repository.dart';
import '../../services/auth_service.dart'; // الآن هذا يشير إلى SupabaseAuthService
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  final String documentUrl;
  final String selectedRole;

  const ProfileCompletionScreen({
    super.key,
    required this.documentUrl,
    required this.selectedRole,
  });

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // --- التغيير الأول: طريقة جلب اسم المستخدم من Supabase ---
    final user = ref.read(authServiceProvider).currentUser;
    // Supabase يخزن الاسم في userMetadata، مع وضع الإيميل كخيار بديل
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // --- التغيير الثاني: استخدام user.id بدلاً من user.uid ---
      await ref.read(userRepositoryProvider).completeUserProfile(
            id: user.id, // Supabase يستخدم "id" كمعرف فريد
            role: widget.selectedRole,
            documentUrl: widget.documentUrl,
            displayName: _nameController.text.trim(),
            whatsappNumber: _phoneController.text.trim(),
          );

      // Invalidate the provider to force a re-fetch of user data
      ref.invalidate(userDataProvider);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) =>
                const DrawerWrapper()), // توجه إلى الشاشة الرئيسية مباشرة
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    // --- لا يوجد أي تغييرات هنا في واجهة المستخدم ---
    return Scaffold(
      appBar: AppBar(
        title: Text('completeProfile'.tr()),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'finalStep'.tr(),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'appNameLabel'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'pleaseEnterName'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'whatsappNumberLabel'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'pleaseEnterValidPhone'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(
                    child: ShimmerLoader(
                  width: 40,
                  height: 40,
                  isCircular: true,
                ))
              else
                ElevatedButton(
                  onPressed: _submitProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: Text('finishAndSave'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
