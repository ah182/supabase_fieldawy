import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/domain/dashboard_stats.dart';
import 'package:fieldawy_store/features/authentication/application/auth_user_provider.dart';

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get comprehensive dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return DashboardStats.empty();

      // Get total products
      final productsCount = await _supabase
          .from('products')
          .select('id')
          .eq('user_id', userId)
          .count();

      // Get active offers
      final offersCount = await _supabase
          .from('offers')
          .select('id')
          .eq('user_id', userId)
          .gte('expiration_date', DateTime.now().toIso8601String())
          .count();

      // Get total views for user's products
      final viewsData = await _supabase
          .from('products')
          .select('views')
          .eq('user_id', userId);
      
      int totalViews = 0;
      for (var product in viewsData) {
        totalViews += (product['views'] as int? ?? 0);
      }

      // Get surgical tools count
      final surgicalToolsCount = await _supabase
          .from('surgical_tools')
          .select('id')
          .eq('user_id', userId)
          .count();

      // Get vet supplies count
      final vetSuppliesCount = await _supabase
          .from('vet_supplies')
          .select('id')
          .eq('user_id', userId)
          .count();

      // Calculate monthly growth (simplified - based on products added this month vs last month)
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);

      final thisMonthProducts = await _supabase
          .from('products')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', thisMonthStart.toIso8601String())
          .count();

      final lastMonthProducts = await _supabase
          .from('products')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', lastMonthStart.toIso8601String())
          .lt('created_at', lastMonthEnd.toIso8601String())
          .count();

      double monthlyGrowth = 0.0;
      if (lastMonthProducts.count > 0) {
        monthlyGrowth = ((thisMonthProducts.count - lastMonthProducts.count) / lastMonthProducts.count) * 100;
      } else if (thisMonthProducts.count > 0) {
        monthlyGrowth = 100.0;
      }

      return DashboardStats(
        totalProducts: productsCount.count + surgicalToolsCount.count + vetSuppliesCount.count,
        activeOffers: offersCount.count,
        totalViews: totalViews,
        totalOrders: 0, // Will be implemented when order system is available
        monthlyGrowth: monthlyGrowth,
        totalRevenue: 0.0, // Will be implemented when payment system is available
        pendingOrders: 0,
        completedOrders: 0,
        averageRating: 4.5, // Placeholder - will be calculated from reviews
        totalCustomers: 0, // Will be implemented when customer tracking is available
      );
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return DashboardStats.empty();
    }
  }

  // Get recent products
  Future<List<Map<String, dynamic>>> getRecentProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final products = await _supabase
          .from('products')
          .select('id, name, price, created_at, views')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(products);
    } catch (e) {
      print('Error getting recent products: $e');
      return [];
    }
  }

  // Get top performing products (by views)
  Future<List<Map<String, dynamic>>> getTopProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final products = await _supabase
          .from('products')
          .select('id, name, price, views, created_at')
          .eq('user_id', userId)
          .order('views', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(products);
    } catch (e) {
      print('Error getting top products: $e');
      return [];
    }
  }

  // Get products expiring soon
  Future<List<Map<String, dynamic>>> getExpiringProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final oneYearFromNow = DateTime.now().add(const Duration(days: 365));
      
      final products = await _supabase
          .from('products')
          .select('id, name, expiry_date, price')
          .eq('user_id', userId)
          .not('expiry_date', 'is', null)
          .lte('expiry_date', oneYearFromNow.toIso8601String())
          .order('expiry_date', ascending: true)
          .limit(5);

      return List<Map<String, dynamic>>.from(products);
    } catch (e) {
      print('Error getting expiring products: $e');
      return [];
    }
  }

  // Get monthly sales data for charts
  Future<List<Map<String, dynamic>>> getMonthlySalesData() async {
    try {
      // For now, return mock data since we don't have sales tracking yet
      final now = DateTime.now();
      List<Map<String, dynamic>> monthlyData = [];
      
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        monthlyData.add({
          'month': _getMonthName(month.month),
          'sales': (i * 1000) + (DateTime.now().millisecond % 500), // Mock data
          'views': (i * 150) + (DateTime.now().millisecond % 100), // Mock data
        });
      }
      
      return monthlyData;
    } catch (e) {
      print('Error getting monthly sales data: $e');
      return [];
    }
  }

  // Get regional statistics
  Future<List<Map<String, dynamic>>> getRegionalStats() async {
    try {
      // For now, return mock data since we don't have regional tracking yet
      return [
        {'region': 'القاهرة', 'customers': 45, 'orders': 23},
        {'region': 'الإسكندرية', 'customers': 32, 'orders': 18},
        {'region': 'الجيزة', 'customers': 28, 'orders': 15},
        {'region': 'الدقهلية', 'customers': 21, 'orders': 12},
        {'region': 'الشرقية', 'customers': 19, 'orders': 10},
      ];
    } catch (e) {
      print('Error getting regional stats: $e');
      return [];
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month];
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});