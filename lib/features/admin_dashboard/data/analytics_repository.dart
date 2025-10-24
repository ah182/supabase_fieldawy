import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// Models
// =====================================================

class UserActivityStats {
  final String userId;
  final String displayName;
  final String? email;
  final String role;
  final int totalSearches;
  final int totalViews;
  final int totalProducts;
  final DateTime lastActivityAt;

  UserActivityStats({
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
    required this.totalSearches,
    required this.totalViews,
    required this.totalProducts,
    required this.lastActivityAt,
  });

  factory UserActivityStats.fromJson(Map<String, dynamic> json) {
    return UserActivityStats(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      totalSearches: json['total_searches'] as int,
      totalViews: json['total_views'] as int,
      totalProducts: json['total_products'] as int,
      lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
    );
  }

  int get totalActivity => totalSearches + totalViews;
}

class ProductPerformanceStats {
  final String productId;
  final String productName;
  final String? company;
  final double? price;
  final String? distributorId;
  final String? distributorName;
  final int totalViews;
  final int doctorViews;
  final DateTime? lastViewedAt;
  final int distributorCount;

  ProductPerformanceStats({
    required this.productId,
    required this.productName,
    this.company,
    this.price,
    this.distributorId,
    this.distributorName,
    required this.totalViews,
    required this.doctorViews,
    this.lastViewedAt,
    required this.distributorCount,
  });

  factory ProductPerformanceStats.fromJson(Map<String, dynamic> json) {
    return ProductPerformanceStats(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      company: json['company'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      distributorId: json['distributor_id'] as String?,
      distributorName: json['distributor_name'] as String?,
      totalViews: json['total_views'] as int,
      doctorViews: json['doctor_views'] as int,
      lastViewedAt: json['last_viewed_at'] != null
          ? DateTime.parse(json['last_viewed_at'] as String)
          : null,
      distributorCount: json['distributor_count'] as int,
    );
  }
}

class UserGrowthData {
  final DateTime date;
  final int newUsers;
  final int totalUsers;
  final Map<String, int> byRole; // {'doctor': 5, 'distributor': 3, ...}

  UserGrowthData({
    required this.date,
    required this.newUsers,
    required this.totalUsers,
    required this.byRole,
  });
}

// =====================================================
// Repository
// =====================================================

class AnalyticsRepository {
  final SupabaseClient _supabase;

  AnalyticsRepository({required SupabaseClient supabase}) : _supabase = supabase;

  // =====================================================
  // Top Performers
  // =====================================================

  // Get top products by views
  Future<List<ProductPerformanceStats>> getTopProductsByViews({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('product_performance_stats')
          .select()
          .order('total_views', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ProductPerformanceStats.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch top products: $e');
    }
  }

  // Get top users by activity
  Future<List<UserActivityStats>> getTopUsersByActivity({
    String? role,
    int limit = 10,
  }) async {
    try {
      var query = _supabase
          .from('user_activity_stats')
          .select()
          .order('total_searches', ascending: false)
          .order('total_views', ascending: false)
          .limit(limit);

      final response = await query;

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => UserActivityStats.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch top users: $e');
    }
  }

  // Search user stats by name or email
  Future<List<UserActivityStats>> searchUserStats(String query) async {
    try {
      final response = await _supabase
          .from('user_activity_stats')
          .select()
          .or('display_name.ilike.%$query%,email.ilike.%$query%')
          .order('total_searches', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => UserActivityStats.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to search user stats: $e');
    }
  }

  // Search product stats by name
  Future<List<ProductPerformanceStats>> searchProductStats(String query) async {
    try {
      final response = await _supabase
          .from('product_performance_stats')
          .select()
          .or('product_name.ilike.%$query%,company.ilike.%$query%')
          .order('total_views', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ProductPerformanceStats.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to search product stats: $e');
    }
  }

  // Get detailed stats for a specific user
  Future<UserActivityStats?> getUserStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_activity_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserActivityStats.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch user stats: $e');
    }
  }

  // Get detailed stats for a specific product
  Future<ProductPerformanceStats?> getProductStats(String productId) async {
    try {
      final response = await _supabase
          .from('product_performance_stats')
          .select()
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) return null;
      return ProductPerformanceStats.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch product stats: $e');
    }
  }

  // =====================================================
  // User Growth Analytics
  // =====================================================

  // Get user growth data (daily, weekly, or monthly)
  Future<List<UserGrowthData>> getUserGrowth({
    required DateTime startDate,
    required DateTime endDate,
    String period = 'daily', // 'daily', 'weekly', 'monthly'
  }) async {
    try {
      // Get all users within date range
      final response = await _supabase
          .from('users')
          .select('created_at, role')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at');

      final List<dynamic> data = response as List<dynamic>;

      // Group by period
      final Map<DateTime, Map<String, int>> grouped = {};
      int cumulativeTotal = 0;

      for (var item in data) {
        final createdAt = DateTime.parse(item['created_at'] as String);
        final role = item['role'] as String;

        // Get period date
        DateTime periodDate;
        switch (period) {
          case 'weekly':
            periodDate = DateTime(createdAt.year, createdAt.month, createdAt.day - createdAt.weekday + 1);
            break;
          case 'monthly':
            periodDate = DateTime(createdAt.year, createdAt.month, 1);
            break;
          default: // daily
            periodDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
        }

        if (!grouped.containsKey(periodDate)) {
          grouped[periodDate] = {
            'total': 0,
            'doctor': 0,
            'distributor': 0,
            'company': 0,
            'viewer': 0,
          };
        }

        grouped[periodDate]!['total'] = (grouped[periodDate]!['total'] ?? 0) + 1;
        grouped[periodDate]![role] = (grouped[periodDate]![role] ?? 0) + 1;
      }

      // Convert to UserGrowthData list
      final List<UserGrowthData> result = [];
      for (var entry in grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
        cumulativeTotal += entry.value['total']!;
        
        result.add(UserGrowthData(
          date: entry.key,
          newUsers: entry.value['total']!,
          totalUsers: cumulativeTotal,
          byRole: {
            'doctor': entry.value['doctor']!,
            'distributor': entry.value['distributor']!,
            'company': entry.value['company']!,
            'viewer': entry.value['viewer']!,
          },
        ));
      }

      return result;
    } catch (e) {
      throw Exception('Failed to fetch user growth data: $e');
    }
  }

  // Get user registration counts by date range
  Future<Map<String, int>> getUserCountsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      final List<dynamic> data = response as List<dynamic>;

      final Map<String, int> counts = {
        'total': data.length,
        'doctor': 0,
        'distributor': 0,
        'company': 0,
        'viewer': 0,
      };

      for (var item in data) {
        final role = item['role'] as String;
        counts[role] = (counts[role] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to fetch user counts: $e');
    }
  }

  // =====================================================
  // Refresh Materialized Views
  // =====================================================

  Future<void> refreshStats() async {
    try {
      await _supabase.rpc('refresh_user_activity_stats');
      await _supabase.rpc('refresh_product_performance_stats');
    } catch (e) {
      throw Exception('Failed to refresh stats: $e');
    }
  }
}

// =====================================================
// Providers
// =====================================================

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(supabase: Supabase.instance.client);
});

// Top Products
final topProductsByViewsProvider = FutureProvider.family<List<ProductPerformanceStats>, int>((ref, limit) {
  return ref.watch(analyticsRepositoryProvider).getTopProductsByViews(limit: limit);
});

// Top Users
final topUsersByActivityProvider = FutureProvider.family<List<UserActivityStats>, TopUsersParams>((ref, params) {
  return ref.watch(analyticsRepositoryProvider).getTopUsersByActivity(
    role: params.role,
    limit: params.limit,
  );
});

class TopUsersParams {
  final String? role;
  final int limit;

  TopUsersParams({this.role, this.limit = 10});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopUsersParams &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          limit == other.limit;

  @override
  int get hashCode => role.hashCode ^ limit.hashCode;
}

// User Growth (Last 7 days)
final userGrowthLast7DaysProvider = FutureProvider<List<UserGrowthData>>((ref) {
  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 7));
  return ref.watch(analyticsRepositoryProvider).getUserGrowth(
    startDate: startDate,
    endDate: endDate,
    period: 'daily',
  );
});

// User Growth (Last 30 days)
final userGrowthLast30DaysProvider = FutureProvider<List<UserGrowthData>>((ref) {
  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 30));
  return ref.watch(analyticsRepositoryProvider).getUserGrowth(
    startDate: startDate,
    endDate: endDate,
    period: 'daily',
  );
});

// Search providers
final searchUserStatsProvider = FutureProvider.family<List<UserActivityStats>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.watch(analyticsRepositoryProvider).searchUserStats(query);
});

final searchProductStatsProvider = FutureProvider.family<List<ProductPerformanceStats>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.watch(analyticsRepositoryProvider).searchProductStats(query);
});
