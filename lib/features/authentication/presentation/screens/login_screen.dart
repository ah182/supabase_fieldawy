import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../widgets/shimmer_loader.dart';
// ✅ استخدم خدمة جوجل المباشرة (بدون متصفح)
import '../../services/google_auth_service.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    super.dispose();
  }

  // --- التعديل هنا فقط ---
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // ✅ تسجيل الدخول عبر GoogleSignIn + signInWithIdToken (بدون متصفح)
      await GoogleAuthService().signInWithGoogle();

      // AuthGate هيتولى التوجيه بعد تغير حالة المصادقة
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'خطأ'.tr(),
        message: message,
        contentType: ContentType.failure,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    // --- لا يوجد أي تغييرات هنا في واجهة المستخدم ---
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    bool isSmallScreen = size.width < 600;
    bool isTablet = size.width >= 600 && size.width < 1024;
    bool isDesktop = size.width >= 1024;

    double logoHeight = isSmallScreen
        ? size.height * 0.5
        : isTablet
            ? size.height * 0.6
            : size.height * 0.6;

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
                    SizedBox(height: size.height * 0.07),
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
                            : _buildGoogleSignInButton(isSmallScreen),
                      ),
                    ),
                    SizedBox(height: size.height * 0.05),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'secureLogin'.tr(),
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildGoogleSignInButton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isSmallScreen ? double.infinity : 400,
      ),
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _signInWithGoogle,
        icon: Image.asset(
          'assets/google_icon.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
        label: Text(
          'signInWithGoogle'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
