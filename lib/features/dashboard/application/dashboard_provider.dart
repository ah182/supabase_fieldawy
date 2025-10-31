import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/dashboard/data/dashboard_repository.dart';
import 'package:fieldawy_store/features/dashboard/domain/dashboard_stats.dart';

// Provider for dashboard statistics
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getDashboardStats();
});

// Provider for recent products
final recentProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getRecentProducts();
});

// Provider for top performing products
final topProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getTopProducts();
});

// Provider for expiring products
final expiringProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getExpiringProducts();
});

// Provider for monthly sales data for charts
final monthlySalesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getMonthlySalesData();
});

// Provider for regional statistics
final regionalStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return await repository.getRegionalStats();
});