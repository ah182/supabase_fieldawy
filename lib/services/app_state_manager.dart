import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _lastRoute;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastRoute();
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
        _saveCurrentRoute();
        break;
      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          _loadLastRoute();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _saveCurrentRoute() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastRoute != null) {
      await prefs.setString('last_route', _lastRoute!);
    }
  }

  Future<void> _loadLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString('last_route');
    if (route != null && mounted) {
      _lastRoute = route;
      // التحقق من صحة الصفحة المحفوظة
      if (_isValidRoute(route)) {
        _navigateToLastRoute(route);
      }
    }
  }

  bool _isValidRoute(String route) {
    // تحقق من أن الصفحة المحفوظة لا تزال صالحة للمستخدم الحالي
    return ['home', 'profile', 'settings', 'products', 'distributors'].contains(route);
  }

  void updateCurrentRoute(String route) {
    setState(() {
      _lastRoute = route;
    });
  }

  void _navigateToLastRoute(String route) {
    // إرسال إشعار للتنقل للصفحة المحفوظة
    // يمكن استخدام post frame callback لضمان تحديث الـ UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // البحث عن NavigationService أو استخدام GlobalKey للتنقل
        // يمكن إضافة منطق التنقل هنا حسب التصميم الحالي
        print('Restoring to route: $route'); // للتسجيل المؤقت
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Provider لحالة الصفحة الحالية
final currentRouteProvider = StateNotifierProvider<CurrentRouteNotifier, String>((ref) {
  return CurrentRouteNotifier();
});

class CurrentRouteNotifier extends StateNotifier<String> {
  CurrentRouteNotifier() : super('home');

  void setCurrentRoute(String route) {
    state = route;
    // حفظ في SharedPreferences
    _saveRoute(route);
  }

  Future<void> _saveRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_route', route);
  }

  Future<void> restoreLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString('last_route') ?? 'home';
    state = route;
  }
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

  void navigateTo(String route) {
    final appStateManager = AppStateManager.of(context);
    appStateManager?.updateCurrentRoute(route);
    ref.read(currentRouteProvider.notifier).setCurrentRoute(route);
    
    // تنفيذ التنقل الفعلي حسب التصميم الحالي
    switch (route) {
      case profileRoute:
        // تنقل لصفحة الملف الشخصي
        _navigateToProfile();
        break;
      case settingsRoute:
        // تنقل لصفحة الإعدادات
        _navigateToSettings();
        break;
      case productsRoute:
        // تنقل لصفحة المنتجات
        _navigateToProducts();
        break;
      case distributorsRoute:
        // تنقل لصفحة الموزعين
        _navigateToDistributors();
        break;
      case homeRoute:
      default:
        // العودة للصفحة الرئيسية
        _navigateToHome();
        break;
    }
  }

  void _navigateToProfile() {
    // تنفيذ التنقل لصفحة الملف الشخصي
    // يمكن استخدام Navigator.push أو تحديث الـ drawer
  }

  void _navigateToSettings() {
    // تنفيذ التنقل لصفحة الإعدادات
  }

  void _navigateToProducts() {
    // تنفيذ التنقل لصفحة المنتجات
  }

  void _navigateToDistributors() {
    // تنفيذ التنقل لصفحة الموزعين
  }

  void _navigateToHome() {
    // العودة للصفحة الرئيسية
  }
}

// Provider للـ NavigationService
final navigationServiceProvider = Provider<NavigationService>((ref) {
  throw UnimplementedError('navigationServiceProvider must be used with BuildContext');
});
