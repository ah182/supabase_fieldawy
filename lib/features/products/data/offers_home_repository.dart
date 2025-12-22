import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferItem {
  final ProductModel product;
  final DateTime? expirationDate;
  
  OfferItem({required this.product, this.expirationDate});

  Map<String, dynamic> toJson() {
    return {
      'product': product.toMap(),
      'expiration_date': expirationDate?.toIso8601String(),
    };
  }

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      product: ProductModel.fromMap(Map<String, dynamic>.from(json['product'])),
      expirationDate: json['expiration_date'] != null 
          ? DateTime.parse(json['expiration_date']) 
          : null,
    );
  }
}

class OffersHomeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  OffersHomeRepository(this._cache);

  /// الحصول على جميع العروض من جميع المستخدمين
  Future<List<OfferItem>> getAllOffers() async {
    // استخدام Cache-First للعروض (تتغير بشكل متوسط)
    return await _cache.cacheFirst<List<OfferItem>>(
      key: 'all_offers_home_v2',
      duration: CacheDurations.medium, // 30 دقيقة
      fetchFromNetwork: _fetchAllOffers,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => OfferItem.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<OfferItem>> _fetchAllOffers() async {
    return await NetworkGuard.execute(() async {
      // جلب جميع العروض من جميع المستخدمين
      final rows = await _supabase
          .from('offers')
          .select('*, views')
          .order('created_at', ascending: false);

      final offers = <OfferItem>[];
      
      // جلب جميع أسماء المستخدمين مرة واحدة
      final userIds = rows
          .map((row) => row['user_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();
      
      Map<String, String> userNames = {};
      if (userIds.isNotEmpty) {
        final usersData = await _supabase
            .from('users')
            .select('id, display_name')
            .inFilter('id', userIds);
        
        for (final user in usersData) {
          userNames[user['id'].toString()] = user['display_name']?.toString() ?? 'موزع غير معروف';
        }
      }
      
      for (final row in rows) {
        final isOcr = row['is_ocr'] as bool? ?? false;
        final productId = row['product_id']?.toString();
        final userId = row['user_id']?.toString();
        final distributorName = userNames[userId] ?? 'موزع غير معروف';
        final offerDescription = row['description']?.toString() ?? '';
        
        DateTime? expirationDate;
        final exp = row['expiration_date'];
        if (exp is String) {
          expirationDate = DateTime.tryParse(exp);
        } else if (exp is DateTime) {
          expirationDate = exp;
        }
        
        if (productId == null) continue;

        if (isOcr) {
          final productDoc = await _supabase
              .from('ocr_products')
              .select()
              .eq('id', productId)
              .maybeSingle();
          
          if (productDoc != null) {
            offers.add(OfferItem(
              product: ProductModel(
                id: row['id']?.toString() ?? '',
                name: productDoc['product_name']?.toString() ?? '',
                description: offerDescription,
                activePrinciple: productDoc['active_principle']?.toString(),
                company: productDoc['product_company']?.toString(),
                action: '',
                package: productDoc['package']?.toString() ?? '',
                imageUrl: (productDoc['image_url']?.toString() ?? '').startsWith('http')
                    ? productDoc['image_url'].toString()
                    : '',
                price: (row['price'] as num?)?.toDouble(),
                distributorId: distributorName,
                distributorUuid: userId,
                createdAt: row['created_at'] != null
                    ? DateTime.tryParse(row['created_at'].toString())
                    : null,
                availablePackages: [productDoc['package']?.toString() ?? ''],
                selectedPackage: productDoc['package']?.toString() ?? '',
                isFavorite: false,
                oldPrice: null,
                priceUpdatedAt: null,
                views: (row['views'] as int?) ?? 0,
              ),
              expirationDate: expirationDate,
            ));
          }
        } else {
          final productDoc = await _supabase
              .from('products')
              .select()
              .eq('id', int.tryParse(productId) ?? 0)
              .maybeSingle();
          
          if (productDoc != null) {
            final product = ProductModel.fromMap(Map<String, dynamic>.from(productDoc));
            offers.add(OfferItem(
              product: product.copyWith(
                id: row['id']?.toString() ?? '',
                price: (row['price'] as num?)?.toDouble(),
                selectedPackage: row['package'] as String?,
                distributorId: distributorName,
                distributorUuid: userId,
                description: offerDescription,
                views: (row['views'] as int?) ?? 0,
              ),
              expirationDate: expirationDate,
            ));
          }
        }
      }

      // Cache as JSON
      final jsonList = offers.map((o) => o.toJson()).toList();
      _cache.set('all_offers_home_v2', jsonList, duration: CacheDurations.medium);

      return offers;
    });
  }

  /// حذف كاش العروض
  void invalidateOffersCache() {
    _cache.invalidate('all_offers_home_v2');
    print('🧹 Offers cache invalidated');
  }
}

// Provider
final offersHomeRepositoryProvider = Provider<OffersHomeRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return OffersHomeRepository(cache);
});
