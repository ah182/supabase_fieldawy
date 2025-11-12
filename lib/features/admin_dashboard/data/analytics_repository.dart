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
  final int totalViews; // المشاهدات على منتجات الموزع
  final int totalProducts; // عدد المنتجات
  final DateTime lastActivityAt;

  UserActivityStats({
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
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
      totalViews: json['total_views'] as int,
      totalProducts: json['total_products'] as int,
      lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
    );
  }
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
      // جلب جميع المشاهدات بدون limit لحساب الإجمالي الصحيح
      // نستخدم limit كبير بدلاً من بدون limit لتجنب مشاكل الأداء
      final viewsResponse = await _supabase
          .from('product_views')
          .select('product_id, user_role, viewed_at')
          .limit(10000); // جلب آخر 10,000 مشاهدة

      final List<dynamic> viewsData = viewsResponse as List<dynamic>;
      if (viewsData.isEmpty) return [];
      
      // تجميع المشاهدات حسب product_id (حساب إجمالي المشاهدات لكل منتج)
      Map<String, Map<String, dynamic>> productStats = {};
      for (var view in viewsData) {
        final productId = view['product_id'].toString();
        if (!productStats.containsKey(productId)) {
          productStats[productId] = {
            'product_id': productId,
            'total_views': 0,
            'doctor_views': 0,
            'last_viewed_at': view['viewed_at'],
          };
        }
        // حساب إجمالي المشاهدات
        productStats[productId]!['total_views'] = (productStats[productId]!['total_views'] as int) + 1;
        if (view['user_role'] == 'doctor') {
          productStats[productId]!['doctor_views'] = (productStats[productId]!['doctor_views'] as int) + 1;
        }
        // تحديث آخر تاريخ مشاهدة
        if (view['viewed_at'] != null) {
          final currentLast = productStats[productId]!['last_viewed_at'];
          if (currentLast == null || 
              DateTime.parse(view['viewed_at']).isAfter(DateTime.parse(currentLast))) {
            productStats[productId]!['last_viewed_at'] = view['viewed_at'];
          }
        }
      }

      // ترتيب حسب إجمالي عدد المشاهدات (من الأعلى للأقل)
      var sortedProducts = productStats.entries.toList()
        ..sort((a, b) => (b.value['total_views'] as int).compareTo(a.value['total_views'] as int));
      
      // أخذ أعلى limit منتج
      final topProductIds = sortedProducts.take(limit).map((e) => e.key).toList();
      if (topProductIds.isEmpty) return [];

      // جلب تفاصيل المنتجات - نجرب أعمدة مختلفة
      List<dynamic> productsData = [];
      try {
        // محاولة 1: جلب جميع الأعمدة المتوقعة
        final response = await _supabase
            .from('products')
            .select('id, name, company, distributor_id')
            .inFilter('id', topProductIds);
        productsData = response as List<dynamic>;
      } catch (e) {
        // محاولة 2: جلب الحد الأدنى من الأعمدة
        try {
          final response = await _supabase
              .from('products')
              .select('id, name')
              .inFilter('id', topProductIds);
          productsData = response as List<dynamic>;
        } catch (e2) {
          // إذا فشل كل شيء، نستخدم البيانات الموجودة فقط
          print('Could not fetch product details: $e2');
        }
      }
      
      // دمج البيانات
      List<ProductPerformanceStats> results = [];
      for (var productId in topProductIds) {
        final stats = productStats[productId];
        if (stats != null) {
          // محاولة إيجاد تفاصيل المنتج
          var productData = productsData.firstWhere(
            (p) => p['id'].toString() == productId,
            orElse: () => {'id': productId, 'name': 'Product $productId'},
          );
          
          results.add(ProductPerformanceStats(
            productId: productId,
            productName: productData['name'] ?? 'Product $productId',
            company: productData['company'],
            price: null, // السعر غير متوفر في جدول products
            distributorId: productData['distributor_id'],
            distributorName: productData['distributor_id'],
            totalViews: stats['total_views'] as int,
            doctorViews: stats['doctor_views'] as int,
            lastViewedAt: stats['last_viewed_at'] != null 
                ? DateTime.parse(stats['last_viewed_at']) 
                : null,
            distributorCount: 1,
          ));
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to fetch top products: $e');
    }
  }

  // Get top users by activity (حسب عدد المنتجات - Distributor Products + Distributor OCR)
  Future<List<UserActivityStats>> getTopUsersByActivity({
    String? role,
    int limit = 10,
  }) async {
    try {
      // 1. جلب منتجات الموزعين (Distributor Products)
      List<dynamic> distributorProductsData = [];
      try {
        final response = await _supabase
            .from('distributor_products')
            .select('distributor_id');
        distributorProductsData = response as List<dynamic>;
      } catch (e) {
        print('Could not fetch distributor_products: $e');
      }
      
      // 2. جلب منتجات OCR الموزعين (Distributor OCR Products)
      List<dynamic> distributorOcrData = [];
      try {
        final response = await _supabase
            .from('distributor_ocr_products')
            .select('distributor_id');
        distributorOcrData = response as List<dynamic>;
      } catch (e) {
        print('Could not fetch distributor_ocr_products: $e');
      }
      
      // 3. تجميع عدد المنتجات لكل موزع
      Map<String, Map<String, dynamic>> userStats = {};
      
      // عدّ منتجات الموزعين (Distributor Products)
      for (var product in distributorProductsData) {
        final userId = product['distributor_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          if (!userStats.containsKey(userId)) {
            userStats[userId] = {
              'user_id': userId,
              'distributor_products': 0,
              'distributor_ocr_products': 0,
              'total_products': 0,
              'total_views': 0,
            };
          }
          userStats[userId]!['distributor_products'] = (userStats[userId]!['distributor_products'] as int) + 1;
        }
      }

      // عدّ منتجات OCR الموزعين (Distributor OCR Products)
      for (var product in distributorOcrData) {
        final userId = product['distributor_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          if (!userStats.containsKey(userId)) {
            userStats[userId] = {
              'user_id': userId,
              'distributor_products': 0,
              'distributor_ocr_products': 0,
              'total_products': 0,
              'total_views': 0,
            };
          }
          userStats[userId]!['distributor_ocr_products'] = (userStats[userId]!['distributor_ocr_products'] as int) + 1;
        }
      }

      // حساب إجمالي المنتجات لكل موزع
      for (var userId in userStats.keys) {
        final distributorProductsCount = userStats[userId]!['distributor_products'] as int;
        final distributorOcrCount = userStats[userId]!['distributor_ocr_products'] as int;
        userStats[userId]!['total_products'] = distributorProductsCount + distributorOcrCount;
      }

      // 4. جلب المشاهدات على منتجات كل موزع
      try {
        // جلب من distributor_products: product_id -> distributor_id
        final allDistributorProducts = await _supabase
            .from('distributor_products')
            .select('product_id, distributor_id');

        print('DEBUG: Found ${allDistributorProducts.length} distributor products mapping');

        // بناء Map: product_id (من products) -> distributor_id
        Map<String, String> productToDistributor = {};
        
        for (var item in allDistributorProducts) {
          final productId = item['product_id']?.toString();
          final distributorId = item['distributor_id']?.toString();
          if (productId != null && distributorId != null && distributorId.isNotEmpty) {
            productToDistributor[productId] = distributorId;
          }
        }
        
        // جلب من distributor_ocr_products: ocr_product_id -> distributor_id
        final allDistributorOcrMapping = await _supabase
            .from('distributor_ocr_products')
            .select('ocr_product_id, distributor_id');

        print('DEBUG: Found ${allDistributorOcrMapping.length} distributor ocr mapping');

        for (var item in allDistributorOcrMapping) {
          final productId = item['ocr_product_id']?.toString();
          final distributorId = item['distributor_id']?.toString();
          if (productId != null && distributorId != null && distributorId.isNotEmpty) {
            productToDistributor[productId] = distributorId;
          }
        }

          print('DEBUG: Product to Distributor map size: ${productToDistributor.length}');

          // جلب المشاهدات
          final viewsResponse = await _supabase
              .from('product_views')
              .select('product_id');
          
          final List<dynamic> viewsData = viewsResponse as List<dynamic>;
          print('DEBUG: Found ${viewsData.length} product views');
          
          // عرض أول 5 product IDs من المشاهدات
          if (viewsData.isNotEmpty) {
            print('DEBUG: Sample product_id from views: ${viewsData.take(5).map((v) => v['product_id']).toList()}');
          }
          
          // عرض أول 5 product IDs من الـ map
          if (productToDistributor.isNotEmpty) {
            print('DEBUG: Sample product_ids in map: ${productToDistributor.keys.take(5).toList()}');
          }
          
          // حساب المشاهدات لكل موزع
          int matchedViews = 0;
          for (var view in viewsData) {
            final productId = view['product_id']?.toString();
            if (productId != null && productToDistributor.containsKey(productId)) {
              matchedViews++;
              final distributorId = productToDistributor[productId]!;
              if (userStats.containsKey(distributorId)) {
                userStats[distributorId]!['total_views'] = 
                    (userStats[distributorId]!['total_views'] as int) + 1;
              }
            }
          }
          
          print('DEBUG: Matched views: $matchedViews out of ${viewsData.length}');
      } catch (e) {
        print('ERROR fetching product views: $e');
      }

      // 5. ترتيب حسب عدد المنتجات والمشاهدات (الأعلى أولاً)
      var sortedUsers = userStats.entries.toList()
        ..sort((a, b) {
          final productsA = a.value['total_products'] as int;
          final productsB = b.value['total_products'] as int;
          final viewsA = a.value['total_views'] as int;
          final viewsB = b.value['total_views'] as int;
          
          // الترتيب: عدد المنتجات أولاً، ثم المشاهدات
          if (productsB != productsA) {
            return productsB.compareTo(productsA);
          }
          return viewsB.compareTo(viewsA);
        });

      // 6. أخذ أعلى limit مستخدم
      final topUserIds = sortedUsers.take(limit).map((e) => e.key).toList();
      if (topUserIds.isEmpty) return [];

      // 7. جلب بيانات المستخدمين
      final usersResponse = await _supabase
          .from('users')
          .select('id, display_name, email, role')
          .inFilter('id', topUserIds);

      final List<dynamic> usersData = usersResponse as List<dynamic>;
      
      // 8. دمج البيانات
      List<UserActivityStats> results = [];
      for (var userId in topUserIds) {
        final stats = userStats[userId];
        if (stats != null) {
          // محاولة إيجاد بيانات المستخدم
          var userData = usersData.firstWhere(
            (u) => u['id'].toString() == userId,
            orElse: () => {'id': userId, 'email': 'User $userId'},
          );
          
          results.add(UserActivityStats(
            userId: userId,
            displayName: userData['display_name'] ?? userData['email'] ?? 'User $userId',
            email: userData['email'],
            role: userData['role'] ?? 'user',
            totalViews: stats['total_views'] as int, // مشاهدات منتجات الموزع
            totalProducts: stats['total_products'] as int, // إجمالي المنتجات
            lastActivityAt: DateTime.now(),
          ));
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to fetch top users: $e');
    }
  }

  // Search user stats by name or email
  Future<List<UserActivityStats>> searchUserStats(String query) async {
    try {
      // البحث في جدول users مباشرة
      final usersResponse = await _supabase
          .from('users')
          .select('id, display_name, email, role')
          .or('display_name.ilike.%$query%,email.ilike.%$query%')
          .limit(20);

      final List<dynamic> usersData = usersResponse as List<dynamic>;
      if (usersData.isEmpty) return [];

      // جلب الإحصائيات لهؤلاء المستخدمين
      final userIds = usersData.map((u) => u['id'].toString()).toList();

      // جلب عدد البحث
      final searchResponse = await _supabase
          .from('search_tracking')
          .select('user_id')
          .inFilter('user_id', userIds);

      // جلب عدد المشاهدات
      final viewsResponse = await _supabase
          .from('product_views')
          .select('user_id')
          .inFilter('user_id', userIds);

      final List<dynamic> searchData = searchResponse as List<dynamic>;
      final List<dynamic> viewsData = viewsResponse as List<dynamic>;

      // حساب الإحصائيات
      Map<String, Map<String, int>> stats = {};
      for (var userId in userIds) {
        stats[userId] = {'searches': 0, 'views': 0};
      }

      for (var search in searchData) {
        final userId = search['user_id'].toString();
        stats[userId]!['searches'] = (stats[userId]!['searches'] ?? 0) + 1;
      }

      for (var view in viewsData) {
        final userId = view['user_id'].toString();
        stats[userId]!['views'] = (stats[userId]!['views'] ?? 0) + 1;
      }

      // بناء النتائج
      List<UserActivityStats> results = [];
      for (var user in usersData) {
        final userId = user['id'].toString();
        final userStats = stats[userId] ?? {'searches': 0, 'views': 0};
        
        results.add(UserActivityStats(
          userId: userId,
          displayName: user['display_name'] ?? user['email'] ?? 'Unknown',
          email: user['email'],
          role: user['role'] ?? 'user',
          totalViews: userStats['views'] ?? 0,
          totalProducts: 0,
          lastActivityAt: DateTime.now(),
        ));
      }

      results.sort((a, b) => b.totalViews.compareTo(a.totalViews));
      return results;
    } catch (e) {
      throw Exception('Failed to search user stats: $e');
    }
  }

  // Search product stats by name
  Future<List<ProductPerformanceStats>> searchProductStats(String query) async {
    try {
      // البحث في جدول products مباشرة - نجرب أعمدة مختلفة
      List<dynamic> productsData = [];
      try {
        final response = await _supabase
            .from('products')
            .select('id, name, company, distributor_id')
            .or('name.ilike.%$query%,company.ilike.%$query%')
            .limit(20);
        productsData = response as List<dynamic>;
      } catch (e) {
        // محاولة بديلة مع الحد الأدنى من الأعمدة
        final response = await _supabase
            .from('products')
            .select('id, name')
            .or('name.ilike.%$query%')
            .limit(20);
        productsData = response as List<dynamic>;
      }

      if (productsData.isEmpty) return [];

      // جلب الإحصائيات
      final productIds = productsData.map((p) => p['id'].toString()).toList();

      final viewsResponse = await _supabase
          .from('product_views')
          .select('product_id, user_role')
          .inFilter('product_id', productIds);

      final List<dynamic> viewsData = viewsResponse as List<dynamic>;

      // حساب الإحصائيات
      Map<String, Map<String, int>> stats = {};
      for (var productId in productIds) {
        stats[productId] = {'total': 0, 'doctor': 0};
      }

      for (var view in viewsData) {
        final productId = view['product_id'].toString();
        stats[productId]!['total'] = (stats[productId]!['total'] ?? 0) + 1;
        if (view['user_role'] == 'doctor') {
          stats[productId]!['doctor'] = (stats[productId]!['doctor'] ?? 0) + 1;
        }
      }

      // بناء النتائج
      List<ProductPerformanceStats> results = [];
      for (var product in productsData) {
        final productId = product['id'].toString();
        final productStats = stats[productId] ?? {'total': 0, 'doctor': 0};

        results.add(ProductPerformanceStats(
          productId: productId,
          productName: product['name'] ?? 'Product $productId',
          company: product['company'],
          price: null, // السعر غير متوفر
          distributorId: product['distributor_id'],
          distributorName: product['distributor_id'],
          totalViews: productStats['total'] ?? 0,
          doctorViews: productStats['doctor'] ?? 0,
          lastViewedAt: null,
          distributorCount: 1,
        ));
      }

      results.sort((a, b) => b.totalViews.compareTo(a.totalViews));
      return results;
    } catch (e) {
      throw Exception('Failed to search product stats: $e');
    }
  }

  // Get detailed stats for a specific user
  Future<UserActivityStats?> getUserStats(String userId) async {
    try {
      // جلب بيانات المستخدم
      final userResponse = await _supabase
          .from('users')
          .select('id, display_name, email, role')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) return null;

      // جلب الإحصائيات (المشاهدات فقط)
      final viewsResponse = await _supabase
          .from('product_views')
          .select('id')
          .eq('user_id', userId);

      final List<dynamic> viewsData = viewsResponse as List<dynamic>;

      return UserActivityStats(
        userId: userId,
        displayName: userResponse['display_name'] ?? userResponse['email'] ?? 'Unknown',
        email: userResponse['email'],
        role: userResponse['role'] ?? 'user',
        totalViews: viewsData.length,
        totalProducts: 0,
        lastActivityAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch user stats: $e');
    }
  }

  // Get detailed stats for a specific product
  Future<ProductPerformanceStats?> getProductStats(String productId) async {
    try {
      // جلب بيانات المنتج
      final productResponse = await _supabase
          .from('products')
          .select('id, name, company, price, distributor_id')
          .eq('id', productId)
          .maybeSingle();

      if (productResponse == null) return null;

      // جلب الإحصائيات
      final viewsResponse = await _supabase
          .from('product_views')
          .select('user_role')
          .eq('product_id', productId);

      final List<dynamic> viewsData = viewsResponse as List<dynamic>;
      int totalViews = viewsData.length;
      int doctorViews = viewsData.where((v) => v['user_role'] == 'doctor').length;

      return ProductPerformanceStats(
        productId: productId,
        productName: productResponse['name'] ?? 'Unknown',
        company: productResponse['company'],
        price: productResponse['price'] != null ? (productResponse['price'] as num).toDouble() : null,
        distributorId: productResponse['distributor_id'],
        distributorName: productResponse['distributor_id'],
        totalViews: totalViews,
        doctorViews: doctorViews,
        lastViewedAt: null,
        distributorCount: 1,
      );
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
