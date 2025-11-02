import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/domain/dashboard_stats.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/authentication/application/auth_user_provider.dart';

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get comprehensive dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return DashboardStats.empty();

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

      return DashboardStats(
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
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return DashboardStats.empty();
    }
  }

  // Get recent products from all sources - WITH VIEWS
  Future<List<Map<String, dynamic>>> getRecentProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

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
            .limit(3);

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
            .limit(3);

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

      // Sort all products by created_at and take top 5
      allProducts.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return allProducts.take(5).toList();
    } catch (e) {
      print('Error getting recent products: $e');
      return [];
    }
  }

  // Get top performing products (by views from ALL sources)
  Future<List<Map<String, dynamic>>> getTopProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

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
          final productSource = offer['is_ocr'] == true ? 'OCR' : 'كتالوج';
          topProducts.add({
            'id': offer['id'],
            'name': 'عرض ($productSource) - ${offer['product_id'] ?? 'غير معروف'}',
            'price': offer['price'] ?? 0,
            'views': offer['views'] ?? 0,
            'created_at': offer['created_at'],
            'source': 'offer',
          });
        }
      } catch (e) {
        print('Error getting top offers: $e');
      }

      // Sort by views and take top 5
      topProducts.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
      return topProducts.take(5).toList();
    } catch (e) {
      print('Error getting top products: $e');
      return [];
    }
  }

  // Get products expiring soon from distributor_ocr_products
  Future<List<Map<String, dynamic>>> getExpiringProducts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

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
      return products.map<Map<String, dynamic>>((product) {
        final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
        return {
          'id': product['id'],
          'name': ocrProduct?['product_name'] ?? 'منتج غير معروف',
          'price': product['price'] ?? 0,
          'expiry_date': product['expiration_date'],
        };
      }).toList();
    } catch (e) {
      print('Error getting expiring products: $e');
      return [];
    }
  }

  // Get monthly sales data for charts
  Future<List<Map<String, dynamic>>> getMonthlySalesData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

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