import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/core/localization/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Login Screen with Real Supabase Authentication
/// صفحة تسجيل دخول حقيقية للمدير
class AdminLoginRealScreen extends ConsumerStatefulWidget {
  const AdminLoginRealScreen({super.key});

  @override
  ConsumerState<AdminLoginRealScreen> createState() => _AdminLoginRealScreenState();
}

class _AdminLoginRealScreenState extends ConsumerState<AdminLoginRealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. تسجيل الدخول
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Login failed - no user returned');
      }

      // 2. التحقق من أن المستخدم admin
      final userId = response.user!.id;
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      final role = userData['role'] as String?;

      if (role != 'admin') {
        // ليس admin - تسجيل خروج
        await supabase.auth.signOut();
        throw Exception('Access denied - Admin only!');
      }

      // 3. نجح! انتقل للـ dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isArabic = locale.languageCode == 'ar';
    
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'تسجيل دخول المدير' : 'Admin Login'),
          actions: [
            // Language Toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ar',
                  label: Text('ع'),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text('EN'),
                ),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (Set<String> newSelection) {
                ref.read(languageProvider.notifier).setLocale(Locale(newSelection.first));
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Title
                const Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'تسجيل دخول المدير' : 'Admin Login',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'سجل دخول ببيانات المدير' : 'Sign in with your admin credentials',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isArabic ? 'الرجاء إدخال البريد الإلكتروني' : 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return isArabic ? 'الرجاء إدخال بريد إلكتروني صحيح' : 'Please enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'كلمة المرور' : 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isArabic ? 'الرجاء إدخال كلمة المرور' : 'Please enter password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isArabic ? 'تسجيل الدخول' : 'Login'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
