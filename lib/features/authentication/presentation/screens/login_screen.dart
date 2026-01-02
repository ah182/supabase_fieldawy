// ignore_for_file: unused_import

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../widgets/shimmer_loader.dart';
import '../../services/auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _showLoginForm = false; // Toggle for Login Form

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInAnonymously() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signInAnonymously();
      // AuthGate will handle navigation after auth state changes.
    } catch (e) {
      if (mounted) _showError('unexpected_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final fakeEmail = "$phone@fieldawy.com";

      await ref.read(authServiceProvider).signInWithEmailAndPassword(
        email: fakeEmail, 
        password: password
      );
      
    } catch (e) {
      if (mounted) _showError('login_failed'.tr()); 
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // AuthGate will handle navigation
    } catch (e) {
      if (mounted) _showError('unexpected_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _contactSupportForPassword() async {
    final phone = _phoneController.text.trim();
    final message = "أهلاً إدارة فيلدوي، لقد نسيت كلمة المرور الخاصة بحسابي.\nرقم الهاتف: $phone";
    final url = Uri.parse("https://wa.me/201016610554?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showError('cannotOpenWhatsApp'.tr());
    }
  }

  void _showError(String message) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'error_title'.tr(), 
        message: message,
        contentType: ContentType.failure,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;

    bool isSmallScreen = size.width < 600;
    // ignore: unused_local_variable
    bool isTablet = size.width >= 600 && size.width < 1024;
    bool isDesktop = size.width >= 1024;

    double logoHeight = isSmallScreen
        ? size.height * 0.4 // Reduced to make space
        : size.height * 0.5;

    double horizontalPadding = isSmallScreen ? 20.0 : size.width * 0.1;

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 8, 119, 136),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.02),
                    
                    // Logo Section
                    if (!_showLoginForm)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: logoHeight,
                            maxWidth: isDesktop ? 500 : double.infinity,
                          ),
                          child: ClipRect(
                            child: Image.asset(
                              'assets/main_logo.png',
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: logoHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    if (_showLoginForm) SizedBox(height: size.height * 0.05),

                    SizedBox(height: size.height * 0.05),

                    // Main Action Area
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.5, 1.0,
                              curve: Curves.elasticOut),
                        )),
                        child: _isLoading
                            ? _buildLoadingWidget()
                            : _showLoginForm 
                                ? _buildLoginForm() 
                                : _buildStartButton(isSmallScreen),
                      ),
                    ),
                    
                    SizedBox(height: size.height * 0.03),

                    // Toggle Button (Start New vs Login)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showLoginForm = !_showLoginForm;
                        });
                      },
                      child: Text(
                        _showLoginForm 
                            ? "letsStart".tr() 
                            : "have_account_login".tr(), // Needs key
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),

                    if (!_showLoginForm) ...[
                       SizedBox(height: size.height * 0.02),
                      _buildSecureBadge(textTheme),
                    ],

                    SizedBox(height: size.height * 0.02),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            "login".tr(), // Key needed
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Phone Input
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.black87),
            validator: (val) => (val == null || val.length < 10) ? 'pleaseEnterValidPhone'.tr() : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'auth.profile.whatsapp_label'.tr(),
              prefixIcon: const Icon(Icons.phone, color: Color(0xFF087788)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          
          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.black87),
            validator: (val) => (val == null || val.length < 6) ? 'password_too_short'.tr() : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'password'.tr(),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF087788)),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),

          // --- Forgot Password Link ---
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _contactSupportForPassword,
              child: Text(
                "forgot_password_link".tr(), // Needs key
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _signInWithCredentials,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "login".tr(), 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          ),

          const SizedBox(height: 20),
          
          // --- Google Sign In Divider ---
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.8))),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.5))),
            ],
          ),
          const SizedBox(height: 20),

          // --- Google Sign In Button (Legacy) ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signInWithGoogle,
              icon: Image.asset(
                'assets/google_icon.png',
                width: 24,
                height: 24,
              ),
              label: Text(
                'signInWithGoogle'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureBadge(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent, 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(
          color: Colors.white.withOpacity(0.15), 
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded, 
              size: 22,
              color: Color(0xFF89CFF0), 
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'secureLogin'.tr(),
              textAlign: TextAlign.center, 
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13, 
                height: 1.3, 
                letterSpacing: 0.5, 
                shadows: [
                  const Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2.0,
                    color: Color.fromARGB(150, 0, 0, 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? colorScheme.surface.withOpacity(0.2)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? colorScheme.onSurface.withOpacity(0.2)
              : Colors.white.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerLoader(
            width: 24,
            height: 24,
            isCircular: true,
            baseColor: isDarkMode
                ? colorScheme.onSurface.withOpacity(0.3)
                : Colors.grey[300]!,
            highlightColor: isDarkMode
                ? colorScheme.onSurface.withOpacity(0.1)
                : Colors.grey[100]!,
          ),
          const SizedBox(height: 12),
          Text(
            'loggingIn'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? colorScheme.onSurface : colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isSmallScreen ? double.infinity : 400,
      ),
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _signInAnonymously,
        icon: const Icon(
          Icons.rocket_launch_rounded,
          color: Colors.white,
          size: 24,
        ),
        label: Text(
          "letsStart".tr(), 
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42A5F5), // Blue accent color
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.blueAccent.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
