import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/my_products_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/clinics/presentation/screens/clinics_map_screen.dart';
import 'package:fieldawy_store/features/reviews/products_reviews_screen.dart';
import 'package:fieldawy_store/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_screen.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/vet_supplies_screen.dart';
import 'package:fieldawy_store/features/jobs/presentation/screens/job_offers_screen.dart';
import 'package:fieldawy_store/features/analytics/presentation/pages/analytics_page.dart';
import 'package:fieldawy_store/features/orders/presentation/screens/orders_screen.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/developer_profile_screen.dart';

class AppStateManager extends StatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  State<AppStateManager> createState() => _AppStateManagerState();

  static _AppStateManagerState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AppStateManagerState>();
}

class _AppStateManagerState extends State<AppStateManager>
    with WidgetsBindingObserver {
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // تم إزالة _loadLastRoute() - لما التطبيق يتقفل ويفتح تاني يبدأ من الـ Home
    // Flutter بيحافظ على الـ state تلقائياً لما التطبيق يكون في الـ background
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppInBackground = true;
        // مش محتاجين نحفظ الـ route - Flutter بيحافظ على الـ state تلقائياً
        break;
      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          // Flutter بيحافظ على الـ state تلقائياً - مش محتاجين نحمل من SharedPreferences
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // تم إزالة _saveCurrentRoute و _loadLastRoute و _isValidRoute و _navigateToLastRoute
  // لأن Flutter بيحافظ على الـ state تلقائياً لما التطبيق في الـ background
  // ولما التطبيق يتقفل خالص بيبدأ من الـ Home screen

  void updateCurrentRoute(String route) {
    // مش محتاجين نحفظ الـ route - للتتبع الداخلي فقط
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Provider لحالة الصفحة الحالية
final currentRouteProvider =
    StateNotifierProvider<CurrentRouteNotifier, String>((ref) {
  return CurrentRouteNotifier();
});

class CurrentRouteNotifier extends StateNotifier<String> {
  CurrentRouteNotifier() : super('home');

  void setCurrentRoute(String route) {
    state = route;
    // تم إزالة حفظ الـ route في SharedPreferences
    // Flutter بيحافظ على الـ state تلقائياً لما التطبيق في الـ background
  }

  // تم إزالة _saveRoute و restoreLastRoute
  // لأن مش محتاجين نحفظ الـ route - التطبيق يبدأ من الـ Home لما يتقفل
}

// Service للـ Navigation
class NavigationService {
  static const String homeRoute = 'home';
  static const String profileRoute = 'profile';
  static const String settingsRoute = 'settings';
  static const String productsRoute = 'products';
  static const String distributorsRoute = 'distributors';

  final BuildContext context;
  final WidgetRef ref;

  NavigationService(this.context, this.ref);

  // ... existing methods ...

  void navigateTo(String route) {
    // تحديث الحالة قبل التنقل
    final appStateManager = AppStateManager.of(context);
    appStateManager?.updateCurrentRoute(route);
    ref.read(currentRouteProvider.notifier).setCurrentRoute(route);

    // تنفيذ التنقل الفعلي
    switch (route) {
      case profileRoute:
        // Already handled in menu
        break;
      case settingsRoute:
        _navigateToSettings();
        break;
      case productsRoute:
        _navigateToProducts();
        break;
      case distributorsRoute:
        _navigateToDistributors();
        break;
      case homeRoute:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DrawerWrapper()),
          (route) => false,
        );
        break;
      // New routes
      case 'clinics_map':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ClinicsMapScreen(),
            settings: const RouteSettings(name: 'clinics_map')));
        break;
      case 'product_rating':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ProductsWithReviewsScreen(),
            settings: const RouteSettings(name: 'product_rating')));
        break;
      case 'dashboard':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const DashboardPage(),
            settings: const RouteSettings(name: 'dashboard')));
        break;
      case 'my_products':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const MyProductsScreen(),
            settings: const RouteSettings(name: 'my_products')));
        break;
      case 'add_products':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const AddProductScreen(),
            settings: const RouteSettings(name: 'add_products')));
        break;
      case 'vet_supplies':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const VetSuppliesScreen(),
            settings: const RouteSettings(name: 'vet_supplies')));
        break;
      case 'job_offers':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const JobOffersScreen(),
            settings: const RouteSettings(name: 'job_offers')));
        break;
      case 'analytics':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const AnalyticsPage(),
            settings: const RouteSettings(name: 'analytics')));
        break;
      case 'orders':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const OrdersScreen(),
            settings: const RouteSettings(name: 'orders')));
        break;
      case 'developer_profile':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const DeveloperProfileScreen(),
            settings: const RouteSettings(name: 'developer_profile')));
        break;
      default:
        // Try to handle dynamic routes or fallback to home
        if (route.startsWith('/')) {
          Navigator.of(context).pushNamed(route);
        } else {
          _navigateToHome();
        }
        break;
    }
  }

  void _navigateToSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const SettingsScreen(),
      settings: const RouteSettings(name: settingsRoute),
    ));
  }

  void _navigateToProducts() {
    // Assuming My products
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const MyProductsScreen(),
      settings: const RouteSettings(name: productsRoute),
    ));
  }

  void _navigateToDistributors() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const DistributorsScreen(),
      settings: const RouteSettings(name: distributorsRoute),
    ));
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DrawerWrapper()),
      (route) => false,
    );
  }
}

// Global Navigator Observer
class AppRouteObserver extends NavigatorObserver {
  final WidgetRef ref;

  AppRouteObserver(this.ref);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateRoute(newRoute);
    }
  }

  void _updateRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName != null &&
        routeName.isNotEmpty &&
        routeName != '/' &&
        routeName != '/splash' &&
        routeName != '/login') {
      // Avoid saving auth/splash routes
      Future.microtask(() {
        ref.read(currentRouteProvider.notifier).setCurrentRoute(routeName);
      });
    }
  }
}

// Provider للـ NavigationService
final navigationServiceProvider = Provider<NavigationService>((ref) {
  throw UnimplementedError(
      'navigationServiceProvider must be used with BuildContext');
});
