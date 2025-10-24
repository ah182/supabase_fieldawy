import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/onboarding_selection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/rejection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/pending_review_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/splash_screen.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/services/app_state_manager.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fieldawy_store/core/providers/connectivity_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/clinics/presentation/widgets/location_permission_dialog.dart';
import 'package:fieldawy_store/features/clinics/data/clinic_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthGate extends HookConsumerWidget {
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
          // Listen for userDataProvider to recover from an error, then refresh home data.
          ref.listen<AsyncValue<UserModel?>>(userDataProvider, (previous, next) {
            final wasError = previous?.hasError ?? false;
            final hasData = next.hasValue;
            if (wasError && hasData) {
              // We just recovered from an error. Let's refresh the home screen data.
              ref.invalidate(paginatedProductsProvider);
              ref.invalidate(allDistributorProductsProvider);
            }
          });

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
                return const OnboardingSelectionScreen();
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

              // طلب الموقع للأطباء عند أول تسجيل دخول
              _checkAndRequestLocationForDoctor(context, ref, userModel);

              return const DrawerWrapper();
            },
            loading: () => const SplashScreen(),
            error: (e, s) {
              final connectivity = ref.watch(connectivityStatusProvider);
              return connectivity.when(
                data: (status) {
                  if (status.contains(ConnectivityResult.none)) {
                    return const DrawerWrapper();
                  }

                  // Online but failed to fetch user data. Retry with a grace period.
                  final retryCount = useState(0);

                  useEffect(() {
                    if (retryCount.value < 3) {
                      final timer = Timer(const Duration(seconds: 3), () {
                        retryCount.value++;
                        ref.invalidate(userDataProvider);
                      });
                      return timer.cancel;
                    }
                    return null;
                  }, [retryCount.value]);

                  if (retryCount.value >= 3) {
                    return Scaffold(
                        body: Center(child: Text('Error loading user: $e')));
                  } else {
                    return const SplashScreen(); // Show loader during grace period
                  }
                },
                loading: () => const SplashScreen(),
                error: (e, s) => Scaffold(
                    body: Center(child: Text('Connectivity Error: $e'))),
              );
            },
          );
        }

        // 👀 fallback: Login
        return const LoginScreen();
      },
      loading: () => const SplashScreen(),
      error: (e, s) {
        final connectivity = ref.watch(connectivityStatusProvider);
        final currentUser = Supabase.instance.client.auth.currentUser;

        return connectivity.when(
          data: (status) {
            if (status.contains(ConnectivityResult.none) && currentUser != null) {
              // Offline but has a cached user, so let them in.
              return const DrawerWrapper();
            }
            // Otherwise, it's a real auth error.
            return Scaffold(body: Center(child: Text('Auth Error: $e')));
          },
          loading: () => const SplashScreen(),
          error: (e, s) =>
              Scaffold(body: Center(child: Text('Connectivity Error: $e'))),
        );
      },
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

  // طلب الموقع للأطباء عند أول تسجيل دخول
  void _checkAndRequestLocationForDoctor(
    BuildContext context,
    WidgetRef ref,
    UserModel userModel,
  ) async {
    // فقط للأطباء
    if (userModel.role != 'doctor') return;

    // تحقق من الـ SharedPreferences إذا كان تم طلب الموقع من قبل
    final prefs = await SharedPreferences.getInstance();
    final locationRequestedKey = 'location_requested_${userModel.id}';
    final hasRequestedBefore = prefs.getBool(locationRequestedKey) ?? false;

    // إذا تم طلب الموقع من قبل، لا نطلبه مرة أخرى
    if (hasRequestedBefore) return;

    // تحقق إذا كان لدى الطبيب موقع مسجل
    final clinic = await ref.read(clinicRepositoryProvider).getClinicByUserId(userModel.id);

    // إذا لم يكن لديه موقع، اطلب الموقع
    if (clinic == null && context.mounted) {
      // تأخير صغير لضمان أن الـ UI جاهزة
      Future.delayed(const Duration(seconds: 1), () {
        if (context.mounted) {
          showLocationPermissionDialog(
            context,
            userModel.id,
            userModel.displayName ?? 'الطبيب',
          );
        }
      });

      // حفظ أننا طلبنا الموقع (سواء وافق أو رفض)
      await prefs.setBool(locationRequestedKey, true);
    }
  }
}
