import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/domain/dashboard_stats.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
// ignore: unused_import
import 'package:fieldawy_store/features/authentication/application/auth_user_provider.dart';

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  DashboardRepository(this._cache);

  // Get comprehensive dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return DashboardStats.empty();

    // استخدام Stale-While-Revalidate للحصول على استجابة سريعة مع تحديث في الخلفية
    return await _cache.staleWhileRevalidate<DashboardStats>(
      key: 'dashboard_stats_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: () => _fetchDashboardStats(userId),
      fromCache: (data) {
        return DashboardStats.fromJson(Map<String, dynamic>.from(data));
      },
    );
  }

  Future<DashboardStats> _fetchDashboardStats(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        // Get total products from distributor_products (main catalog products)
        final distributorProductsCount = await _supabase
            .from('distributor_products')
            .select('id')
            .eq('distributor_id', userId)
            .count();

        // Get total products from distributor_ocr_products (OCR products)
        final ocrProductsCount = await _supabase
            .from('distributor_ocr_products')
            .select('id')
            .eq('distributor_id', userId)
            .count();

        // Get active offers (has user_id and expiration_date)
        final offersCount = await _supabase
            .from('offers')
            .select('id')
            .eq('user_id', userId)
            .gte('expiration_date', DateTime.now().toIso8601String())
            .count();

        // Get total views from ALL SOURCES - THIS IS THE FIX!
        int totalViews = 0;
        
        // 1. Views from distributor_products
        try {
          final distributorProductsViews = await _supabase
              .from('distributor_products')
              .select('views')
              .eq('distributor_id', userId);
          
          for (var product in distributorProductsViews) {
            totalViews += (product['views'] as int? ?? 0);
          }
          print('Distributor products views: ${distributorProductsViews.length} products');
        } catch (e) {
          print('Error getting distributor products views: $e');
        }

        // 2. Views from distributor_ocr_products
        try {
          final ocrProductsViews = await _supabase
              .from('distributor_ocr_products')
              .select('views')
              .eq('distributor_id', userId);
          
          for (var product in ocrProductsViews) {
            totalViews += (product['views'] as int? ?? 0);
          }
          print('OCR products views: ${ocrProductsViews.length} products');
        } catch (e) {
          print('Error getting OCR products views: $e');
        }

        // 3. Views from distributor_surgical_tools
        try {
          final surgicalToolsViews = await _supabase
              .from('distributor_surgical_tools')
              .select('views')
              .eq('distributor_id', userId);
          
          for (var tool in surgicalToolsViews) {
            totalViews += (tool['views'] as int? ?? 0);
          }
          print('Surgical tools views: ${surgicalToolsViews.length} tools');
        } catch (e) {
          print('Error getting surgical tools views: $e');
        }

        // 4. Views from vet_supplies - FIXED: using views_count instead of views
        try {
          final vetSuppliesViews = await _supabase
              .from('vet_supplies')
              .select('views_count') // FIXED: changed from 'views' to 'views_count'
              .eq('user_id', userId);
          
          for (var supply in vetSuppliesViews) {
            totalViews += (supply['views_count'] as int? ?? 0); // FIXED: using views_count
          }
          print('Vet supplies views: ${vetSuppliesViews.length} supplies');
        } catch (e) {
          print('Error getting vet supplies views: $e');
        }

        // 5. Views from offers
        try {
          final offersViewsData = await _supabase
              .from('offers')
              .select('views')
              .eq('user_id', userId);
          
          for (var offer in offersViewsData) {
            totalViews += (offer['views'] as int? ?? 0);
          }
          print('Offers views: ${offersViewsData.length} offers');
        } catch (e) {
          print('Error getting offers views: $e');
        }

        print('Total views calculated: $totalViews');

        // Get surgical tools count
        final surgicalToolsCount = await _supabase
            .from('distributor_surgical_tools')
            .select('id')
            .eq('distributor_id', userId)
            .count();

        // Get vet supplies count
        final vetSuppliesCount = await _supabase
            .from('vet_supplies')
            .select('id')
            .eq('user_id', userId)
            .count();

        // Calculate monthly growth (based on all product sources)
        final now = DateTime.now();
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);

        // This month products from all sources
        final thisMonthDistributorProducts = await _supabase
            .from('distributor_products')
            .select('id')
            .eq('distributor_id', userId)
            .gte('added_at', thisMonthStart.toIso8601String())
            .count();

        final thisMonthOcrProducts = await _supabase
            .from('distributor_ocr_products')
            .select('id')
            .eq('distributor_id', userId)
            .gte('created_at', thisMonthStart.toIso8601String())
            .count();

        // Last month products from all sources
        final lastMonthDistributorProducts = await _supabase
            .from('distributor_products')
            .select('id')
            .eq('distributor_id', userId)
            .gte('added_at', lastMonthStart.toIso8601String())
            .lt('added_at', lastMonthEnd.toIso8601String())
            .count();

        final lastMonthOcrProducts = await _supabase
            .from('distributor_ocr_products')
            .select('id')
            .eq('distributor_id', userId)
            .gte('created_at', lastMonthStart.toIso8601String())
            .lt('created_at', lastMonthEnd.toIso8601String())
            .count();

        final thisMonthTotal = thisMonthDistributorProducts.count + thisMonthOcrProducts.count;
        final lastMonthTotal = lastMonthDistributorProducts.count + lastMonthOcrProducts.count;

        double monthlyGrowth = 0.0;
        if (lastMonthTotal > 0) {
          monthlyGrowth = ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
        } else if (thisMonthTotal > 0) {
          monthlyGrowth = 100.0;
        }

        final stats = DashboardStats(
          totalProducts: distributorProductsCount.count + ocrProductsCount.count + surgicalToolsCount.count + vetSuppliesCount.count,
          activeOffers: offersCount.count,
          totalViews: totalViews, // NOW READING FROM ALL TABLES!
          totalOrders: 0, // Will be implemented when order system is available
          monthlyGrowth: monthlyGrowth,
          totalRevenue: 0.0, // Will be implemented when payment system is available
          pendingOrders: 0,
          completedOrders: 0,
          averageRating: 4.5, // Placeholder - will be calculated from reviews
          totalCustomers: 0, // Will be implemented when customer tracking is available
        );
        
        // Cache as JSON
        _cache.set('dashboard_stats_$userId', stats.toJson(), duration: CacheDurations.medium);
        
        return stats;
      } catch (e) {
        print('Error getting dashboard stats: $e');
        return DashboardStats.empty();
      }
    });
  }

  // Get recent products from all sources - WITH VIEWS
  Future<List<Map<String, dynamic>>> getRecentProducts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Stale-While-Revalidate للمنتجات الحديثة
    return await _cache.staleWhileRevalidate<List<Map<String, dynamic>>>(
      key: 'recent_products_$userId',
      duration: CacheDurations.short, // 15 دقيقة
      staleTime: const Duration(minutes: 5), // تحديث بعد 5 دقائق
      fetchFromNetwork: () => _fetchRecentProducts(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentProducts(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        List<Map<String, dynamic>> allProducts = [];

        // Get recent products from distributor_products with product info AND VIEWS
        try {
          final distributorProducts = await _supabase
              .from('distributor_products')
              .select('''
                id,
                price,
                added_at,
                package,
                views,
                products (
                  name
                )
              ''')
              .eq('distributor_id', userId)
              .order('added_at', ascending: false)
              .limit(2);

          for (var product in distributorProducts) {
            final productInfo = product['products'] as Map<String, dynamic>?;
            allProducts.add({
              'id': product['id'],
              'name': productInfo?['name'] ?? 'منتج غير معروف',
              'price': product['price'] ?? 0,
              'created_at': product['added_at'],
              'views': product['views'] ?? 0, // NOW READING VIEWS!
              'source': 'catalog',
            });
          }
        } catch (e) {
          print('Error getting distributor products: $e');
        }

        // Get recent products from distributor_ocr_products with OCR product info AND VIEWS
        try {
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('''
                id,
                price,
                created_at,
                views,
                ocr_products (
                  product_name,
                  product_company
                )
              ''')
              .eq('distributor_id', userId)
              .order('created_at', ascending: false)
              .limit(2);

          for (var product in ocrProducts) {
            final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
            allProducts.add({
              'id': product['id'],
              'name': ocrProduct?['product_name'] ?? 'منتج غير معروف',
              'price': product['price'] ?? 0,
              'created_at': product['created_at'],
              'views': product['views'] ?? 0, // NOW READING VIEWS!
              'source': 'ocr',
            });
          }
        } catch (e) {
          print('Error getting OCR products: $e');
        }

        // Get recent courses
        try {
          final courses = await _supabase
              .from('vet_courses')
              .select('id, title, price, created_at, views')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          for (var course in courses) {
            allProducts.add({
              'id': course['id'],
              'name': course['title'] ?? 'كورس غير معروف',
              'price': course['price'] ?? 0,
              'created_at': course['created_at'],
              'views': course['views'] ?? 0,
              'source': 'course',
            });
          }
        } catch (e) {
          print('Error getting recent courses: $e');
        }

        // Get recent books
        try {
          final books = await _supabase
              .from('vet_books')
              .select('id, name, price, created_at, views')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          for (var book in books) {
            allProducts.add({
              'id': book['id'],
              'name': book['name'] ?? 'كتاب غير معروف',
              'price': book['price'] ?? 0,
              'created_at': book['created_at'],
              'views': book['views'] ?? 0,
              'source': 'book',
            });
          }
        } catch (e) {
          print('Error getting recent books: $e');
        }

        // Get recent surgical tools
        try {
          final surgicalTools = await _supabase
              .from('distributor_surgical_tools')
              .select('''
                id,
                price,
                created_at,
                views,
                surgical_tools (
                  tool_name
                )
              ''')
              .eq('distributor_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          for (var tool in surgicalTools) {
            final toolInfo = tool['surgical_tools'] as Map<String, dynamic>?;
            allProducts.add({
              'id': tool['id'],
              'name': toolInfo?['tool_name'] ?? 'أداة جراحية غير معروفة',
              'price': tool['price'] ?? 0,
              'created_at': tool['created_at'],
              'views': tool['views'] ?? 0,
              'source': 'surgical',
            });
          }
        } catch (e) {
          print('Error getting recent surgical tools: $e');
        }

        // Sort all products by created_at and take top 5
        allProducts.sort((a, b) {
          final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });

        final result = allProducts.take(5).toList();
        
        // Cache the result
        _cache.set('recent_products_$userId', result, duration: CacheDurations.short);
        
        return result;
      } catch (e) {
        print('Error getting recent products: $e');
        return [];
      }
    });
  }

  // Get top performing products (by views from ALL sources)
  Future<List<Map<String, dynamic>>> getTopProducts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First للمنتجات الأعلى مشاهدة (تتغير ببطء)
    return await _cache.cacheFirst<List<Map<String, dynamic>>>(
      key: 'top_products_$userId',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: () => _fetchTopProducts(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTopProducts(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        List<Map<String, dynamic>> topProducts = [];

        // 1. Get top distributor products by views
        try {
          final distributorProducts = await _supabase
              .from('distributor_products')
              .select('''
                id,
                price,
                views,
                added_at,
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
              'id': product['id'],
              'name': productInfo?['name'] ?? 'منتج من الكتالوج',
              'price': product['price'] ?? 0,
              'views': product['views'] ?? 0,
              'created_at': product['added_at'],
              'source': 'catalog',
            });
          }
        } catch (e) {
          print('Error getting top distributor products: $e');
        }

        // 2. Get top OCR products by views
        try {
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('''
                id,
                price,
                views,
                created_at,
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
              'id': product['id'],
              'name': ocrProduct?['product_name'] ?? 'منتج OCR',
              'price': product['price'] ?? 0,
              'views': product['views'] ?? 0,
              'created_at': product['created_at'],
              'source': 'ocr',
            });
          }
        } catch (e) {
          print('Error getting top OCR products: $e');
        }

        // 3. Get top offers by views
        try {
          final offers = await _supabase
              .from('offers')
              .select('id, price, views, created_at, product_id, is_ocr')
              .eq('user_id', userId)
              .order('views', ascending: false)
              .limit(2);

          for (var offer in offers) {
            // Get product name based on source
            String productName = 'عرض';
            if (offer['product_id'] != null) {
              try {
                if (offer['is_ocr'] == true) {
                  // محاولة البحث المباشر في ocr_products
                  final ocrProduct = await _supabase
                      .from('ocr_products')
                      .select('product_name')
                      .eq('id', offer['product_id'])
                      .maybeSingle();
                  
                  if (ocrProduct != null) {
                    productName = ocrProduct['product_name'] ?? 'عرض OCR';
                  } else {
                    // Fallback: البحث في distributor_ocr_products
                    try {
                      final distProduct = await _supabase
                          .from('distributor_ocr_products')
                          .select('ocr_products(product_name)')
                          .eq('id', offer['product_id'])
                          .maybeSingle();
                      
                      if (distProduct != null && distProduct['ocr_products'] != null) {
                        final ocrData = distProduct['ocr_products'];
                        if (ocrData is Map) {
                          productName = ocrData['product_name'] ?? 'عرض OCR';
                        } else if (ocrData is List && ocrData.isNotEmpty) {
                          productName = ocrData[0]['product_name'] ?? 'عرض OCR';
                        }
                      }
                    } catch (_) {}
                  }
                } else {
                  final product = await _supabase
                      .from('products')
                      .select('name')
                      .eq('id', offer['product_id'])
                      .maybeSingle();
                  productName = product?['name'] ?? 'عرض';
                }
              } catch (e) {
                productName = 'عرض - ${offer['product_id']}';
              }
            }

            topProducts.add({
              'id': offer['id'],
              'name': productName,
              'price': offer['price'] ?? 0,
              'views': offer['views'] ?? 0,
              'created_at': offer['created_at'],
              'source': 'offer',
            });
          }
        } catch (e) {
          print('Error getting top offers: $e');
        }

        // 4. Get top courses by views
        try {
          final courses = await _supabase
              .from('vet_courses')
              .select('id, title, price, views, created_at')
              .eq('user_id', userId)
              .order('views', ascending: false)
              .limit(2);

          for (var course in courses) {
            topProducts.add({
              'id': course['id'],
              'name': course['title'] ?? 'كورس غير معروف',
              'price': course['price'] ?? 0,
              'views': course['views'] ?? 0,
              'created_at': course['created_at'],
              'source': 'course',
            });
          }
        } catch (e) {
          print('Error getting top courses: $e');
        }

        // 5. Get top books by views
        try {
          final books = await _supabase
              .from('vet_books')
              .select('id, name, price, views, created_at')
              .eq('user_id', userId)
              .order('views', ascending: false)
              .limit(2);

          for (var book in books) {
            topProducts.add({
              'id': book['id'],
              'name': book['name'] ?? 'كتاب غير معروف',
              'price': book['price'] ?? 0,
              'views': book['views'] ?? 0,
              'created_at': book['created_at'],
              'source': 'book',
            });
          }
        } catch (e) {
          print('Error getting top books: $e');
        }

        // 6. Get top surgical tools by views
        try {
          final surgicalTools = await _supabase
              .from('distributor_surgical_tools')
              .select('''
                id,
                price,
                views,
                created_at,
                surgical_tools (
                  tool_name
                )
              ''')
              .eq('distributor_id', userId)
              .order('views', ascending: false)
              .limit(2);

          for (var tool in surgicalTools) {
            final toolInfo = tool['surgical_tools'] as Map<String, dynamic>?;
            topProducts.add({
              'id': tool['id'],
              'name': toolInfo?['tool_name'] ?? 'أداة جراحية غير معروفة',
              'price': tool['price'] ?? 0,
              'views': tool['views'] ?? 0,
              'created_at': tool['created_at'],
              'source': 'surgical',
            });
          }
        } catch (e) {
          print('Error getting top surgical tools: $e');
        }

        // Sort by views and take top 10
        topProducts.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
        final result = topProducts.take(10).toList();
        
        // Cache the result
        _cache.set('top_products_$userId', result, duration: CacheDurations.long);
        
        return result;
      } catch (e) {
        print('Error getting top products: $e');
        return [];
      }
    });
  }

  // Get global top products that distributor doesn't own
  Future<List<Map<String, dynamic>>> getGlobalTopProductsNotOwned() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First للتوصيات العالمية (تتغير ببطء)
    return await _cache.cacheFirst<List<Map<String, dynamic>>>(
      key: 'global_top_products_$userId',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: () => _fetchGlobalTopProducts(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchGlobalTopProducts(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        // Get distributor's product IDs from both regular and OCR products
        final distributorProductIds = <String>{};
        final distributorProductNames = <String>{};

        // 1. Get regular distributor products
        try {
          final distributorProducts = await _supabase
              .from('distributor_products')
              .select('''
                product_id,
                products (
                  id,
                  name
                )
              ''')
              .eq('distributor_id', userId);

          for (var product in distributorProducts) {
            if (product['product_id'] != null) {
              distributorProductIds.add(product['product_id'].toString());
            }
            final productInfo = product['products'] as Map<String, dynamic>?;
            if (productInfo != null && productInfo['name'] != null) {
              distributorProductNames.add(productInfo['name'].toString().toLowerCase().trim());
            }
          }
        } catch (e) {
          print('Error getting distributor products: $e');
        }

        // 2. Get OCR products
        try {
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('''
                ocr_product_id,
                ocr_products (
                  product_name
                )
              ''')
              .eq('distributor_id', userId);

          for (var product in ocrProducts) {
            final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
            if (ocrProduct != null && ocrProduct['product_name'] != null) {
              final productName = ocrProduct['product_name'].toString().toLowerCase().trim();
              distributorProductNames.add(productName);
            }
          }
        } catch (e) {
          print('Error getting OCR products: $e');
        }

        print('Distributor has ${distributorProductIds.length} product IDs and ${distributorProductNames.length} product names');

        // Get all products with their distributor counts
        // Since products table doesn't have views, we'll rank by distributor count
        final allProducts = await _supabase
            .from('products')
            .select('id, name, company')
            .limit(200);

        // ⚡ OPTIMIZATION: Get ALL distributor_products data in ONE query
        final allDistributorProducts = await _supabase
            .from('distributor_products')
            .select('product_id, views');

        // Build a map of product stats from all distributor products
        final productStatsMap = <String, Map<String, dynamic>>{};

        for (var distProduct in allDistributorProducts) {
          final productId = distProduct['product_id']?.toString();
          if (productId == null) continue;

          if (!productStatsMap.containsKey(productId)) {
            productStatsMap[productId] = {
              'global_views': 0,
              'distributor_count': 0,
            };
          }

          productStatsMap[productId]!['global_views'] += (distProduct['views'] ?? 0) as int;
          productStatsMap[productId]!['distributor_count'] += 1;
        }

        // Calculate stats for each product
        final productStats = <Map<String, dynamic>>[];

        for (var product in allProducts) {
          final productId = product['id'].toString();
          final productName = (product['name'] ?? '').toString().toLowerCase().trim();

          // Check if distributor has this product (by ID or by name)
          final hasProductById = distributorProductIds.contains(productId);
          final hasProductByName = distributorProductNames.contains(productName);

          if (!hasProductById && !hasProductByName && productName.isNotEmpty) {
            // Get stats from our pre-built map
            final stats = productStatsMap[productId];

            if (stats != null) {
              final globalViews = stats['global_views'] as int;
              final distributorCount = stats['distributor_count'] as int;

              // Only add if product has some activity
              if (distributorCount > 0 || globalViews > 0) {
                productStats.add({
                  'id': productId,
                  'name': product['name'],
                  'company': product['company'],
                  'global_views': globalViews,
                  'distributor_count': distributorCount,
                  'score': (globalViews * 2) + (distributorCount * 100), // Ranking score
                });
              }
            }
          }
        }

        // Sort by score (combination of views and distributor count)
        productStats.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

        // Return top 10 recommendations
        final recommendations = productStats.take(10).toList();

        print('Found ${recommendations.length} recommendations');
        
        // Cache the result
        _cache.set('global_top_products_$userId', recommendations, duration: CacheDurations.long);
        
        return recommendations;
      } catch (e) {
        print('Error getting global top products: $e');
        return [];
      }
    });
  }

  // Get products expiring soon from distributor_ocr_products
  Future<List<Map<String, dynamic>>> getExpiringProducts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First للمنتجات المنتهية (تتغير ببطء)
    return await _cache.cacheFirst<List<Map<String, dynamic>>>(
      key: 'expiring_products_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      fetchFromNetwork: () => _fetchExpiringProducts(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchExpiringProducts(String userId) async {
    return await NetworkGuard.execute(() async {
      try{

        final oneYearFromNow = DateTime.now().add(const Duration(days: 365));
        
        // Get products with expiration_date
        final products = await _supabase
            .from('distributor_ocr_products')
            .select('''
              id,
              price,
              expiration_date,
              ocr_products (
                product_name
              )
            ''')
            .eq('distributor_id', userId)
            .not('expiration_date', 'is', null)
            .lte('expiration_date', oneYearFromNow.toIso8601String())
            .order('expiration_date', ascending: true)
            .limit(5);

        // Transform the data
        final result = products.map<Map<String, dynamic>>((product) {
          final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
          return {
            'id': product['id'],
            'name': ocrProduct?['product_name'] ?? 'منتج غير معروف',
            'price': product['price'] ?? 0,
            'expiry_date': product['expiration_date'],
          };
        }).toList();
        
        // Cache the result
        _cache.set('expiring_products_$userId', result, duration: CacheDurations.medium);
        
        return result;
      } catch (e) {
        print('Error getting expiring products: $e');
        return [];
      }
    });
  }

  // Get monthly sales data for charts
  Future<List<Map<String, dynamic>>> getMonthlySalesData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First للبيانات الشهرية (تتغير مرة يومياً)
    return await _cache.cacheFirst<List<Map<String, dynamic>>>(
      key: 'monthly_sales_$userId',
      duration: CacheDurations.veryLong, // 24 ساعة
      fetchFromNetwork: () => _fetchMonthlySalesData(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMonthlySalesData(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        final now = DateTime.now();
        List<Map<String, dynamic>> monthlyData = [];
        
        for (int i = 5; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final nextMonth = DateTime(now.year, now.month - i + 1, 1);
          
          // Get actual product counts for this month
          final distributorProductsThisMonth = await _supabase
              .from('distributor_products')
              .select('id')
              .eq('distributor_id', userId)
              .gte('added_at', month.toIso8601String())
              .lt('added_at', nextMonth.toIso8601String())
              .count();

          final ocrProductsThisMonth = await _supabase
              .from('distributor_ocr_products')
              .select('id')
              .eq('distributor_id', userId)
              .gte('created_at', month.toIso8601String())
              .lt('created_at', nextMonth.toIso8601String())
              .count();

          final totalProducts = distributorProductsThisMonth.count + ocrProductsThisMonth.count;
          
          monthlyData.add({
            'month': _getMonthName(month.month),
            'sales': totalProducts * 100, // Mock conversion to sales
            'views': totalProducts * 20, // Mock conversion to views
          });
        }
        
        // Cache the result
        _cache.set('monthly_sales_$userId', monthlyData, duration: CacheDurations.veryLong);
        
        return monthlyData;
      } catch (e) {
        print('Error getting monthly sales data: $e');
        return [];
      }
    });
  }

  // Get regional statistics - Real data based on product views
  Future<List<Map<String, dynamic>>> getRegionalStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First للإحصائيات الإقليمية (تتغير ببطء)
    return await _cache.cacheFirst<List<Map<String, dynamic>>>(
      key: 'regional_stats_$userId',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: () => _fetchRegionalStats(userId),
      fromCache: (data) => (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRegionalStats(String userId) async {
    return await NetworkGuard.execute(() async {
      try {

        // Get all product IDs for this distributor from all sources
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
          print('Error getting distributor products for regional stats: $e');
        }

        // 2. Get IDs from distributor_ocr_products
        try {
          final ocrProducts = await _supabase
              .from('distributor_ocr_products')
              .select('id')
              .eq('distributor_id', userId);

          for (var product in ocrProducts) {
            if (product['id'] != null) {
              productIds.add(product['id'].toString());
            }
          }
        } catch (e) {
          print('Error getting OCR products for regional stats: $e');
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
          print('Error getting surgical tools for regional stats: $e');
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

        // Convert to list and sort by views
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
        final topRegions = result.take(10).toList();
        
        // Cache the result
        _cache.set('regional_stats_$userId', topRegions, duration: CacheDurations.long);
        
        return topRegions;
      } catch (e) {
        print('Error getting regional stats: $e');
        return [];
      }
    });
  }

  String _getMonthName(int month) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month];
  }

  /// حذف كاش Dashboard عند تحديث البيانات
  /// يجب استدعاء هذه الدالة عند إضافة/تعديل/حذف المنتجات
  void invalidateDashboardCache() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // حذف جميع الكاش المتعلق بـ Dashboard
    _cache.invalidate('dashboard_stats_$userId');
    _cache.invalidate('recent_products_$userId');
    _cache.invalidate('top_products_$userId');
    _cache.invalidate('global_top_products_$userId');
    _cache.invalidate('expiring_products_$userId');
    _cache.invalidate('monthly_sales_$userId');
    _cache.invalidate('regional_stats_$userId');
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return DashboardRepository(cache);
});