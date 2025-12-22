import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  AnalyticsRepository(this._cache);

  // Get advanced views analytics for current user (مع الكاش)
  Future<Map<String, dynamic>> getAdvancedViewsAnalytics() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return _getEmptyViewsAnalytics();

    // استخدام Stale-While-Revalidate
    return await _cache.staleWhileRevalidate<Map<String, dynamic>>(
      key: 'advanced_views_analytics_$userId',
      duration: CacheDurations.short, // 15 دقيقة
      staleTime: const Duration(minutes: 5), // تحديث بعد 5 دقائق
      fetchFromNetwork: () => _fetchAdvancedViewsAnalytics(userId),
      fromCache: (data) => Map<String, dynamic>.from(data),
    );
  }

  Future<Map<String, dynamic>> _fetchAdvancedViewsAnalytics(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        // Get hourly views data (last 24 hours)
        final hourlyViews = await _getHourlyViews(userId);
        
        // Get views statistics
        final statistics = await _getViewsStatistics(userId);
        
        // Get top viewed products today
        final topViewedToday = await _getTopViewedToday(userId);
        
        // Get geographic distribution
        final geographic = await _getGeographicViews(userId);

        final result = {
          'hourlyViews': hourlyViews,
          'statistics': statistics,
          'topViewedToday': topViewedToday,
          'geographic': geographic,
        };

        // Cache the result
        _cache.set('advanced_views_analytics_$userId', result, duration: CacheDurations.short);

        return result;
      } catch (e) {
        print('Error getting advanced views analytics: $e');
        return _getEmptyViewsAnalytics();
      }
    });
  }

  // Get global trends analytics - SIMPLIFIED VERSION (مع الكاش)
  Future<Map<String, dynamic>> getTrendsAnalytics() async {
    final userId = _supabase.auth.currentUser?.id;
    
    // استخدام Stale-While-Revalidate (البيانات تتغير بسرعة متوسطة)
    return await _cache.staleWhileRevalidate<Map<String, dynamic>>(
      key: 'trends_analytics_${userId ?? "guest"}',
      duration: CacheDurations.short, // 15 دقيقة
      staleTime: const Duration(minutes: 5), // تحديث بعد 5 دقائق
      fetchFromNetwork: () => _fetchTrendsAnalytics(userId),
      fromCache: (data) => Map<String, dynamic>.from(data),
    );
  }

  Future<Map<String, dynamic>> _fetchTrendsAnalytics(String? userId) async {
    return await NetworkGuard.execute(() async {
      try {
        // Get globally trending products - using direct database queries
        final trending = await _getGlobalTrendingProductsSimplified(userId);
        
        // Get search trends - mock data only
        final searches = await _getSearchTrends();
        
        // Get personalized recommendations - simplified
        final recommendations = await _getPersonalizedRecommendationsSimplified(userId);

        final result = {
          'trending': trending,
          'categories': [], // REMOVED: No more category trends
          'searches': searches,
          'recommendations': recommendations,
        };

        // Cache the result
        _cache.set('trends_analytics_${userId ?? "guest"}', result, duration: CacheDurations.short);

        return result;
      } catch (e) {
        print('Error getting trends analytics: $e');
        return _getEmptyTrendsAnalytics();
      }
    });
  }

  // Get hourly views for last 24 hours
  Future<List<Map<String, dynamic>>> _getHourlyViews(String userId) async {
    try {
      // Generate realistic mock data since we don't track hourly timestamps yet
      final now = DateTime.now();
      List<Map<String, dynamic>> hourlyData = [];
      
      for (int i = 23; i >= 0; i--) {
        final hour = now.subtract(Duration(hours: i)).hour;
        
        // Simulate realistic viewing patterns (higher during business hours)
        int views = 0;
        if (hour >= 9 && hour <= 17) {
          views = 15 + (DateTime.now().millisecond % 20); // Business hours
        } else if (hour >= 18 && hour <= 22) {
          views = 8 + (DateTime.now().millisecond % 15); // Evening
        } else {
          views = 2 + (DateTime.now().millisecond % 8); // Night/early morning
        }
        
        hourlyData.add({
          'hour': hour,
          'views': views,
        });
      }
      
      return hourlyData;
    } catch (e) {
      print('Error getting hourly views: $e');
      return [];
    }
  }

    // FIXED: Get views statistics with correct column names

    Future<Map<String, dynamic>> _getViewsStatistics(String userId) async {

      return await NetworkGuard.execute(() async {

        try {

          // Get real data from all user's products

          int todayViews = 0;

          int thisWeekViews = 0;

          

          final now = DateTime.now();

          final todayStart = DateTime(now.year, now.month, now.day);

          final weekStart = todayStart.subtract(Duration(days: 7));

          

          // FIXED: Get views from all product tables with correct column names

          final tables = [

            {'table': 'distributor_products', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'added_at'},

            {'table': 'distributor_ocr_products', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'created_at'},

            {'table': 'distributor_surgical_tools', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'created_at'},

            {'table': 'vet_supplies', 'userCol': 'user_id', 'viewsCol': 'views_count', 'dateCol': 'created_at'},

            {'table': 'offers', 'userCol': 'user_id', 'viewsCol': 'views', 'dateCol': 'created_at'},

          ];

          

          for (final tableInfo in tables) {

            try {

              final data = await _supabase

                  .from(tableInfo['table']!)

                  .select('${tableInfo['viewsCol']}, ${tableInfo['dateCol']}')

                  .eq(tableInfo['userCol']!, userId);

              

              for (var item in data) {

                final views = item[tableInfo['viewsCol']] as int? ?? 0;

                final createdAt = DateTime.tryParse(item[tableInfo['dateCol']] ?? '');

                

                if (createdAt != null) {

                  if (createdAt.isAfter(todayStart)) {

                    todayViews += views;

                  }

                  if (createdAt.isAfter(weekStart)) {

                    thisWeekViews += views;

                  }

                }

              }

            } catch (e) {

              print('Error getting views from ${tableInfo['table']}: $e');

            }

          }

          

          // Calculate growth (mock for now)

          final todayGrowth = 15.0 + (DateTime.now().millisecond % 30);

          final weekGrowth = 25.0 + (DateTime.now().millisecond % 20);

          

          return {

            'today': todayViews,

            'thisWeek': thisWeekViews,

            'todayGrowth': todayGrowth,

            'weekGrowth': weekGrowth,

            'bestDay': '${todayViews + 45}', // Mock best day

            'peakHour': 14, // 2 PM peak hour

          };

        } catch (e) {

          print('Error getting views statistics: $e');

          return {

            'today': 0,

            'thisWeek': 0,

            'todayGrowth': 0.0,

            'weekGrowth': 0.0,

            'bestDay': '0',

            'peakHour': 9,

          };

        }

      });

    }

  

    // Get top viewed products today

    Future<List<Map<String, dynamic>>> _getTopViewedToday(String userId) async {

      return await NetworkGuard.execute(() async {

        try {

          List<Map<String, dynamic>> topProducts = [];

          

          // Get from distributor_products

          try {

            final distributorProducts = await _supabase

                .from('distributor_products')

                .select('''

                  views,

                  products (

                    name

                  )

                ''')

                .eq('distributor_id', userId)

                .order('views', ascending: false)

                .limit(3);

            

            for (var product in distributorProducts) {

              final productInfo = product['products'] as Map<String, dynamic>?;

              topProducts.add({

                'name': productInfo?['name'] ?? 'منتج من الكتالوج',

                'views': product['views'] ?? 0,

                'source': 'الكتالوج',

              });

            }

          } catch (e) {

            print('Error getting top distributor products: $e');

          }

          

          // Get from distributor_ocr_products

          try {

            final ocrProducts = await _supabase

                .from('distributor_ocr_products')

                .select('''

                  views,

                  ocr_products (

                    product_name

                  )

                ''')

                .eq('distributor_id', userId)

                .order('views', ascending: false)

                .limit(3);

            

            for (var product in ocrProducts) {

              final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;

              topProducts.add({

                'name': ocrProduct?['product_name'] ?? 'منتج OCR',

                'views': product['views'] ?? 0,

                'source': 'OCR',

              });

            }

          } catch (e) {

            print('Error getting top OCR products: $e');

          }

          

          // Sort by views and take top 5

          topProducts.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));

          return topProducts.take(5).toList();

        } catch (e) {

          print('Error getting top viewed today: $e');

          return [];

        }

      });

    }

  

    // Get geographic distribution of views - REAL DATA from product_views

    Future<List<Map<String, dynamic>>> _getGeographicViews(String userId) async {

      return await NetworkGuard.execute(() async {

        try {

          // Get all product IDs for this distributor

          List<String> productIds = [];

  

          // 1. Get IDs from distributor_products

          try {

            final distributorProducts = await _supabase

                .from('distributor_products')

                .select('product_id')

                .eq('distributor_id', userId);

  

            for (var product in distributorProducts) {

              if (product['product_id'] != null) {

                productIds.add(product['product_id'].toString());

              }

            }

          } catch (e) {

            print('Error getting distributor products: $e');

          }

  

          // 2. Get IDs from distributor_ocr_products

          try {

            final ocrProducts = await _supabase

                .from('distributor_ocr_products')

                .select('id, ocr_product_id')

                .eq('distributor_id', userId);

  

            for (var product in ocrProducts) {

              if (product['id'] != null) {

                productIds.add(product['id'].toString());

              }

              if (product['ocr_product_id'] != null) {

                productIds.add(product['ocr_product_id'].toString());

              }

            }

          } catch (e) {

            print('Error getting OCR products: $e');

          }

  

          // 3. Get IDs from distributor_surgical_tools

          try {

            final surgicalTools = await _supabase

                .from('distributor_surgical_tools')

                .select('id')

                .eq('distributor_id', userId);

  

            for (var tool in surgicalTools) {

              if (tool['id'] != null) {

                productIds.add(tool['id'].toString());

              }

            }

          } catch (e) {

            print('Error getting surgical tools: $e');

          }

  

          if (productIds.isEmpty) {

            return [];

          }

  

          // Get product views with user information

          final productViews = await _supabase

              .from('product_views')

              .select('user_id, product_id')

              .inFilter('product_id', productIds);

  

          // Get unique user IDs who viewed the products

          Set<String> viewerUserIds = {};

          for (var view in productViews) {

            if (view['user_id'] != null) {

              viewerUserIds.add(view['user_id'].toString());

            }

          }

  

          if (viewerUserIds.isEmpty) {

            return [];

          }

  

          // Get user governorates

          final users = await _supabase

              .from('users')

              .select('id, governorates')

              .inFilter('id', viewerUserIds.toList());

  

          // Count views by governorate

          Map<String, int> governorateViews = {};

          int totalViews = 0;

  

          for (var user in users) {

            final governorates = user['governorates'] as List<dynamic>?;

            if (governorates != null && governorates.isNotEmpty) {

              // Count how many times this user viewed products

              final userViews = productViews.where((v) => v['user_id'] == user['id']).length;

  

              // Distribute views across user's governorates

              for (var gov in governorates) {

                final govName = gov.toString();

                governorateViews[govName] = (governorateViews[govName] ?? 0) + userViews;

                totalViews += userViews;

              }

            }

          }

  

          // Convert to list and calculate percentages

          List<Map<String, dynamic>> result = [];

          governorateViews.forEach((region, views) {

            result.add({

              'region': region,

              'views': views,

              'percentage': totalViews > 0 ? (views / totalViews) : 0.0,

            });

          });

  

          // Sort by views descending

          result.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));

  

          // Return top 10 regions

          return result.take(10).toList();

        } catch (e) {

          print('Error getting geographic views: $e');

          return [];

        }

      });

    }

  // SIMPLIFIED: Get globally trending products using direct database queries
  Future<List<Map<String, dynamic>>> _getGlobalTrendingProductsSimplified(String? userId) async {
    return await NetworkGuard.execute(() async {
      try {
        List<Map<String, dynamic>> trendingProducts = [];
        
        print('Getting trending products using direct database queries...');
        
        // Get trending from distributor_products (catalog products)
        try {
          final catalogProducts = await _supabase
              .from('distributor_products')
              .select('''
                product_id,
                views,
                products (
                  name
                )
              ''')
              .gt('views', 0)
              .order('views', ascending: false)
              .limit(8);
          
          // Group by product_id and sum views
          Map<String, Map<String, dynamic>> productMap = {};
          
          for (var product in catalogProducts) {
            final productId = product['product_id'].toString();
            final productInfo = product['products'] as Map<String, dynamic>?;
            final views = product['views'] as int? ?? 0;
            
            if (productMap.containsKey(productId)) {
              productMap[productId]!['total_views'] += views;
              productMap[productId]!['distributor_count'] += 1;
            } else {
              productMap[productId] = {
                'product_id': productId,
                'name': productInfo?['name'] ?? 'منتج غير معروف',
                'total_views': views,
                'distributor_count': 1,
                'source': 'catalog',
              };
            }
          }
          
          // Convert to list and add trending info
          for (var productData in productMap.values) {
            // Check if current user has this product
            bool userHasProduct = false;
            if (userId != null) {
              try {
                final userProduct = await _supabase
                    .from('distributor_products')
                    .select('id')
                    .eq('distributor_id', userId)
                    .eq('product_id', productData['product_id'])
                    .maybeSingle();
                userHasProduct = userProduct != null;
              } catch (e) {
                print('Error checking if user has product: $e');
              }
            }
            
            trendingProducts.add({
              'name': productData['name'],
              'total_views': productData['total_views'],
              'growth_percentage': productData['total_views'] > 100 ? 25 : 
                                 productData['total_views'] > 50 ? 15 : 5,
              'trend_direction': 'up',
              'user_has_product': userHasProduct,
              'product_id': productData['product_id'],
              'source': 'catalog',
            });
          }
          
          print('Successfully got ${trendingProducts.length} trending catalog products');
        } catch (e) {
          print('Error getting trending catalog products: $e');
        }
        
        // Get trending OCR products
        try {
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('''
                ocr_product_id,
                views,
                ocr_products (
                  product_name
                )
              ''')
              .gt('views', 0)
              .order('views', ascending: false)
              .limit(5);
          
          for (var product in ocrProducts) {
            final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
            trendingProducts.add({
              'name': ocrProduct?['product_name'] ?? 'منتج OCR',
              'total_views': product['views'] ?? 0,
              'growth_percentage': 20,
              'trend_direction': 'up',
              'user_has_product': false, // OCR products are unique
              'product_id': product['ocr_product_id'],
              'source': 'ocr',
            });
          }
          
          print('Successfully got OCR trending products');
        } catch (e) {
          print('Error getting OCR trending products: $e');
        }
        
        // If no real data, add some mock trending products
        if (trendingProducts.isEmpty) {
          print('No trending products found, using mock data');
          final mockProducts = [
            'أموكسيسيلين 500mg',
            'إنروفلوكساسين 10%',
            'دوكسيسيكلين 200mg',
            'سيفالكسين 250mg',
            'أزيثروميسين 100mg',
          ];
          
          for (int i = 0; i < mockProducts.length; i++) {
            trendingProducts.add({
              'name': mockProducts[i],
              'total_views': 500 - (i * 80) + (DateTime.now().millisecond % 100),
              'growth_percentage': 50 - (i * 10),
              'trend_direction': 'up',
              'user_has_product': i == 2, // Simulate user has one product
              'product_id': 'mock_${i + 1}',
              'source': 'catalog',
            });
          }
        }
        
        // Sort by total views and return top 10
        trendingProducts.sort((a, b) => (b['total_views'] as int).compareTo(a['total_views'] as int));
        return trendingProducts.take(10).toList();
      } catch (e) {
        print('Error getting global trending products: $e');
        return [];
      }
    });
  }

  // Get search trends from real distributor data
  Future<List<Map<String, dynamic>>> _getSearchTrends() async {
    return await NetworkGuard.execute(() async {
      try {
        print('Getting real search trends from distributor tables...');
        
        // استخدام الدالة الجديدة لجلب البيانات الحقيقية
        final result = await _supabase
            .rpc('get_real_search_trends', params: {
              'p_limit': 8,
              'p_days_back': 7,
            });
        
        if (result != null && result.isNotEmpty) {
          List<Map<String, dynamic>> trends = [];
          
          for (var item in result) {
            trends.add({
              'keyword': item['keyword'] ?? 'غير معروف',
              'original_term': item['original_term'],
              'count': item['search_count'] ?? 0,
              'improvement_score': item['improvement_score'] ?? 0,
              'source_table': item['source_table'] ?? 'unknown',
              'distributor_count': item['distributor_count'] ?? 0,
              'improved': item['improved'] ?? false,
            });
          }
          
          print('Successfully got ${trends.length} real search trends');
          return trends;
        }
        
        // في حالة عدم وجود بيانات حقيقية، استخدم بيانات تجريبية مع إشارة أنها mock
        print('No real search data found, using enhanced mock data');
        return [
          {'keyword': 'مضاد حيوي', 'count': 245, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'فيتامينات', 'count': 189, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'أدوية قطط', 'count': 156, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'حقن بيطرية', 'count': 134, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'علاج التهابات', 'count': 112, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'مسكنات ألم', 'count': 98, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'أدوية كلاب', 'count': 87, 'improved': false, 'source_table': 'mock'},
          {'keyword': 'مطهرات جروح', 'count': 76, 'improved': false, 'source_table': 'mock'},
        ];
      } catch (e) {
        print('Error getting search trends: $e');
        // fallback to mock data in case of error
        return [
          {'keyword': 'مضاد حيوي', 'count': 245, 'improved': false, 'source_table': 'error_fallback'},
          {'keyword': 'فيتامينات', 'count': 189, 'improved': false, 'source_table': 'error_fallback'},
          {'keyword': 'أدوية قطط', 'count': 156, 'improved': false, 'source_table': 'error_fallback'},
        ];
      }
    });
  }

  // SIMPLIFIED: Get personalized recommendations
  Future<List<Map<String, dynamic>>> _getPersonalizedRecommendationsSimplified(String? userId) async {
    return await NetworkGuard.execute(() async {
      try {
        if (userId == null) return [];
        
        List<Map<String, dynamic>> recommendations = [];
        
        // Analyze user's products count
        try {
          int totalProducts = 0;
          
          // Count from all tables
          final distributorProducts = await _supabase
              .from('distributor_products')
              .select('id')
              .eq('distributor_id', userId)
              .count();
          totalProducts += distributorProducts.count;
          
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('id')
              .eq('distributor_id', userId)
              .count();
          totalProducts += ocrProducts.count;
          
          // Generate recommendations based on product count
          if (totalProducts < 10) {
            recommendations.add({
              'type': 'expand_catalog',
              'title': 'وسع كتالوجك',
              'description': 'لديك ${totalProducts} منتج فقط. أضف المزيد لزيادة فرص الظهور',
              'action_available': true,
              'action_text': 'إضافة منتجات جديدة',
            });
          } else if (totalProducts < 30) {
            recommendations.add({
              'type': 'add_trending',
              'title': 'أضف المنتجات الرائجة',
              'description': 'يمكنك إضافة المنتجات الرائجة عالمياً لزيادة المشاهدات',
              'action_available': true,
              'action_text': 'عرض المنتجات الرائجة',
            });
          } else {
            recommendations.add({
              'type': 'optimize_existing',
              'title': 'حسن منتجاتك الحالية',
              'description': 'لديك كتالوج جيد، ركز على تحسين جودة المحتوى',
              'action_available': true,
              'action_text': 'تحسين المحتوى',
            });
          }
          
        } catch (e) {
          print('Error analyzing user products: $e');
        }
        
        // Add general recommendations
        recommendations.addAll([
          {
            'type': 'seasonal',
            'title': 'منتجات موسمية',
            'description': 'أضف منتجات تناسب الموسم الحالي',
            'action_available': true,
            'action_text': 'عرض المنتجات الموسمية',
          },
          {
            'type': 'content_quality',
            'title': 'جودة المحتوى',
            'description': 'حسن صور ووصف منتجاتك لزيادة جاذبيتها',
            'action_available': true,
            'action_text': 'تحسين المحتوى',
          },
        ]);
        
        return recommendations.take(3).toList();
      } catch (e) {
        print('Error getting recommendations: $e');
        return [];
      }
    });
  }

  Map<String, dynamic> _getEmptyViewsAnalytics() {
    return {
      'hourlyViews': <Map<String, dynamic>>[],
      'statistics': {
        'today': 0,
        'thisWeek': 0,
        'todayGrowth': 0.0,
        'weekGrowth': 0.0,
        'bestDay': '0',
        'peakHour': 9,
      },
      'topViewedToday': <Map<String, dynamic>>[],
      'geographic': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _getEmptyTrendsAnalytics() {
    return {
      'trending': <Map<String, dynamic>>[],
      'categories': <Map<String, dynamic>>[], // EMPTY - no more categories
      'searches': <Map<String, dynamic>>[],
      'recommendations': <Map<String, dynamic>>[],
    };
  }

  /// حذف كاش Analytics
  void invalidateAnalyticsCache() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _cache.invalidate('advanced_views_analytics_$userId');
      _cache.invalidate('trends_analytics_$userId');
    }
    _cache.invalidate('trends_analytics_guest');
    print('🧹 Analytics cache invalidated');
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return AnalyticsRepository(cache);
});