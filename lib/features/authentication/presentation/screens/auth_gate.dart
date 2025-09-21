import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/language_selection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/rejection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/pending_review_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/splash_screen.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/services/app_state_manager.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        final currentUser = Supabase.instance.client.auth.currentUser;

        // 👤 لو مفيش مستخدم → LoginScreen من غير signOut loop
        if (currentUser == null) {
          return const LoginScreen();
        }

        if (user != null) {
          final userData = ref.watch(userDataProvider);

          return userData.when(
            data: (userModel) {
              if (userModel == null) {
                // المستخدم موجود في auth لكن مش موجود في DB
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(authServiceProvider).signOut();
                });
                return const SplashScreen();
              }

              // 🔴 حالة الرفض
              if (userModel.accountStatus == 'rejected') {
                return const RejectionScreen();
              }

              // 🟡 الملف غير مكتمل → يروح يكمّل البروفايل
              if (!userModel.isProfileComplete) {
                return const LanguageSelectionScreen();
              }

              // 🟠 إعادة مراجعة
              if (userModel.accountStatus == 'pending_re_review') {
                return const PendingReviewScreen();
              }

              // ✅ المستخدم تمام → نشوف آخر Route
              final lastRoute = ref.watch(currentRouteProvider);
              if (lastRoute != 'home') {
                if (_isValidRouteForUser(lastRoute, userModel)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final navService = NavigationService(context, ref);
                    navService.navigateTo(lastRoute);
                  });
                }
              }

              return const DrawerWrapper();
            },
            loading: () => const SplashScreen(),
            error: (e, s) =>
                Scaffold(body: Center(child: Text('Error loading user: $e'))),
          );
        }

        // 👀 fallback: Login
        return const LoginScreen();
      },
      loading: () => const SplashScreen(),
      error: (e, s) => Scaffold(body: Center(child: Text('Auth Error: $e'))),
    );
  }

  bool _isValidRouteForUser(String route, dynamic userModel) {
    final allowedRoutes = ['home'];

    if (userModel.role == 'doctor') {
      allowedRoutes.addAll(['distributors', 'addDrug', 'category']);
    } else if (userModel.role == 'distributor' || userModel.role == 'company') {
      allowedRoutes.addAll(['products', 'dashboard', 'category']);
    }

    allowedRoutes.addAll(['profile', 'settings']);
    return allowedRoutes.contains(route);
  }
}
