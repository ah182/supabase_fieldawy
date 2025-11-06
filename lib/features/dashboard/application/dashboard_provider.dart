import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/dashboard/data/dashboard_repository.dart';
import 'package:fieldawy_store/features/dashboard/data/analytics_repository.dart';
import 'package:fieldawy_store/features/dashboard/domain/dashboard_stats.dart';

// Manual refresh counter - increment to trigger refresh
final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

// Provider for dashboard statistics with manual refresh capability
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getDashboardStats();
});

// Provider for recent products with manual refresh capability
final recentProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getRecentProducts();
});

// Provider for top performing products with manual refresh capability
final topProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getTopProducts();
});

// Provider for expiring products
final expiringProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);

  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getExpiringProducts();
});

// Provider for global top products that distributor doesn't own
final globalTopProductsNotOwnedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);

  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getGlobalTopProductsNotOwned();
});

// Provider for monthly sales data for charts
final monthlySalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates  
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getMonthlySalesData();
});

// Provider for regional statistics
final regionalStatsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getRegionalStats();
});

// NEW: Provider for advanced views analytics
final advancedViewsAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(analyticsRepositoryProvider);
  return await repository.getAdvancedViewsAnalytics();
});

// NEW: Provider for trends analytics
final trendsAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(analyticsRepositoryProvider);
  return await repository.getTrendsAnalytics();
});

// Helper provider to trigger refresh of all dashboard data
final dashboardRefreshNotifierProvider = StateNotifierProvider<DashboardRefreshNotifier, bool>((ref) {
  return DashboardRefreshNotifier(ref);
});

class DashboardRefreshNotifier extends StateNotifier<bool> {
  final Ref ref;
  Timer? _autoRefreshTimer;

  DashboardRefreshNotifier(this.ref) : super(false) {
    // Start auto-refresh timer when created
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // إلغاء الـ refresh التلقائي
    // Auto refresh disabled for distributor dashboard
    _autoRefreshTimer?.cancel();
    // _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
    //   // Auto refresh every minute
    //   refreshDashboard();
    // });
  }

  void refreshDashboard() {
    // Increment refresh counter to trigger all providers
    final currentCount = ref.read(dashboardRefreshProvider);
    ref.read(dashboardRefreshProvider.notifier).state = currentCount + 1;
    
    // Set refreshing state
    state = true;
    
    // Reset refreshing state after a short delay
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) state = false;
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}