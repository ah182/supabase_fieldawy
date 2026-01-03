// ignore_for_file: unused_import

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // التحقق من بيانات الأدمن للتحويل لتسجيل جوجل
    final adminPhone = dotenv.env['ADMIN_PHONE'] ?? '';
    final adminPass = dotenv.env['ADMIN_PASSWORD'] ?? '';

    if (phone == adminPhone && password == adminPass) {
      await _signInWithGoogle();
      return;
    }

    setState(() => _isLoading = true);

    try {
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
    final url = Uri.parse("https://wa.me/201017016217?text=${Uri.encodeComponent(message)}");
    
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

    double logoHeight = _showLoginForm
        ? (isSmallScreen ? size.height * 0.25 + 5 : size.height * 0.3 + 5)
        : (isSmallScreen ? size.height * 0.4 + 5 : size.height * 0.5 + 5);

    double horizontalPadding = isSmallScreen ? 20.0 : size.width * 0.1;

    return PopScope(
      canPop: !_showLoginForm,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_showLoginForm) {
          setState(() => _showLoginForm = false);
        }
      },
      child: Scaffold(
        body: Container(
          height: size.height,
          width: size.width,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 8, 119, 136),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // المحتوى الرئيسي
                SingleChildScrollView(
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
    
                          // Toggle Button (Start New vs Login) - REMOVED FROM HERE
    
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
                
                // زر الرجوع - يجب أن يكون في نهاية الـ Stack ليكون فوق الـ SingleChildScrollView
                if (_showLoginForm)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => setState(() => _showLoginForm = false),
                    ),
                  ),

                // --- Footer: Login Toggle (RichText for perfect BiDi support) ---
                if (!_showLoginForm)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: GestureDetector(
                        onTap: () => setState(() => _showLoginForm = true),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${'have_account_question'.tr()} ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: "login".tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
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
              prefixIcon: const Icon(Icons.phone, color: Color.fromARGB(255, 36, 203, 228)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF00B894), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
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
              prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 69, 212, 234)),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: const Color.fromARGB(255, 142, 137, 137)),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF00B894), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),

          // --- Forgot Password Link (Styled with Contrast) ---
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _contactSupportForPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "${'forgot_password_question'.tr()} ",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    TextSpan(
                      text: "contact_support_action".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _signInWithCredentials,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 49, 174, 188),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "login".tr(), 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          )
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
      width: 220, // تصغير عرض الزر
      height: 50, // تصغير ارتفاع الزر
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ElevatedButton.icon(
        onPressed: _signInAnonymously,
        icon: const Icon(
          Icons.shopping_bag_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          "letsStart".tr(), 
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 48, 182, 192), // Vibrant Mint/Teal Green
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // دائرية بالكامل لشكل عصري
          ),
        ),
      ),
    );
  }
}