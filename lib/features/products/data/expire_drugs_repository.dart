import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpireDrugItem {
  final ProductModel product;
  final DateTime? expirationDate;
  final bool? isOcr;

  ExpireDrugItem({
    required this.product,
    required this.expirationDate,
    this.isOcr,
  });

  Map<String, dynamic> toJson() {
    return {
      'product': product.toMap(),
      'expiration_date': expirationDate?.toIso8601String(),
      'is_ocr': isOcr,
    };
  }

  factory ExpireDrugItem.fromJson(Map<String, dynamic> json) {
    return ExpireDrugItem(
      product: ProductModel.fromMap(Map<String, dynamic>.from(json['product'])),
      expirationDate: json['expiration_date'] != null 
          ? DateTime.parse(json['expiration_date']) 
          : null,
      isOcr: json['is_ocr'] as bool?,
    );
  }
}

class ExpireDrugsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  ExpireDrugsRepository(this._cache);

  /// الحصول على جميع المنتجات التي لها تاريخ صلاحية (من جميع الموزعين)
  Future<List<ExpireDrugItem>> getAllExpireDrugs() async {
    // استخدام Stale-While-Revalidate (البيانات تتغير بشكل متوسط)
    return await _cache.staleWhileRevalidate<List<ExpireDrugItem>>(
      key: 'all_expire_drugs',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: _fetchAllExpireDrugs,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => ExpireDrugItem.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<ExpireDrugItem>> _fetchAllExpireDrugs() async {
    // جلب جميع المنتجات من distributor_products (من جميع الموزعين)
    final rows = await _supabase
        .from('distributor_products')
        .select('*, views');

    // جلب جميع المنتجات من distributor_ocr_products (من جميع الموزعين)
    final ocrRows = await _supabase
        .from('distributor_ocr_products')
        .select('*, views');

    // جلب تفاصيل المنتجات العادية
    final productIds = rows.map((row) => row['product_id'].toString()).toSet().toList();
    final productDocs = await _supabase.from('products').select().inFilter('id', productIds);
    final productsMap = {
      for (var doc in productDocs)
        doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
    };

    // جلب تفاصيل منتجات OCR
    final ocrProductIds = ocrRows.map((row) => row['ocr_product_id'] as String).toSet().toList();
    final ocrProductDocs = await _supabase.from('ocr_products').select().inFilter('id', ocrProductIds);
    final ocrProductsMap = {
      for (var doc in ocrProductDocs)
        doc['id'].toString(): ProductModel(
          id: doc['id']?.toString() ?? '',
          name: doc['product_name']?.toString() ?? '',
          description: '',
          activePrinciple: doc['active_principle']?.toString(),
          company: doc['product_company']?.toString(),
          action: '',
          package: doc['package']?.toString() ?? '',
          imageUrl: (doc['image_url']?.toString() ?? '').startsWith('http') ? doc['image_url'].toString() : '',
          price: null,
          distributorId: doc['distributor_name']?.toString(),
          createdAt: doc['created_at'] != null ? DateTime.tryParse(doc['created_at'].toString()) : null,
          availablePackages: [doc['package']?.toString() ?? ''],
          selectedPackage: doc['package']?.toString() ?? '',
          isFavorite: false,
          oldPrice: null,
          priceUpdatedAt: null,
        )
    };

    final items = <ExpireDrugItem>[];

    // من المنتجات العادية
    for (final row in rows) {
      if (row['expiration_date'] != null) {
        final productDetails = productsMap[row['product_id'].toString()];
        if (productDetails != null) {
          DateTime? expirationDate;
          final exp = row['expiration_date'];
          if (exp is String) {
            expirationDate = DateTime.tryParse(exp);
          } else if (exp is DateTime) {
            expirationDate = exp;
          }
          items.add(ExpireDrugItem(
            product: productDetails.copyWith(
              price: (row['price'] as num?)?.toDouble(),
              selectedPackage: row['package'] as String?,
              distributorId: row['distributor_name'] as String?,
              views: (row['views'] as int?) ?? 0,
            ),
            expirationDate: expirationDate,
            isOcr: false,
          ));
        }
      }
    }

    // من منتجات OCR
    for (final row in ocrRows) {
      if (row['expiration_date'] != null) {
        final productDetails = ocrProductsMap[row['ocr_product_id']];
        if (productDetails != null) {
          DateTime? expirationDate;
          final exp = row['expiration_date'];
          if (exp is String) {
            expirationDate = DateTime.tryParse(exp);
          } else if (exp is DateTime) {
            expirationDate = exp;
          }
          final selectedPackage = row.containsKey('package') && row['package'] != null && (row['package'] as String).isNotEmpty
              ? row['package'] as String
              : (productDetails.selectedPackage ?? '');
          items.add(ExpireDrugItem(
            product: productDetails.copyWith(
              price: (row['price'] as num?)?.toDouble(),
              selectedPackage: selectedPackage,
              distributorId: row['distributor_name'] as String?,
              views: (row['views'] as int?) ?? 0,
            ),
            expirationDate: expirationDate,
            isOcr: true,
          ));
        }
      }
    }

    // Cache as JSON
    final jsonList = items.map((item) => item.toJson()).toList();
    _cache.set('all_expire_drugs', jsonList, duration: CacheDurations.medium);

    return items;
  }

  /// الحصول على المنتجات التي لها تاريخ صلاحية للمستخدم الحالي فقط
  Future<List<ExpireDrugItem>> getMyExpireDrugs(String userId) async {
    // استخدام Stale-While-Revalidate
    return await _cache.staleWhileRevalidate<List<ExpireDrugItem>>(
      key: 'my_expire_drugs_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: () => _fetchMyExpireDrugs(userId),
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => ExpireDrugItem.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<ExpireDrugItem>> _fetchMyExpireDrugs(String userId) async {
    // جلب منتجات المستخدم الحالي فقط من distributor_products
    final rows = await _supabase
        .from('distributor_products')
        .select('*, views')
        .eq('distributor_id', userId);

    // جلب منتجات المستخدم الحالي فقط من distributor_ocr_products
    final ocrRows = await _supabase
        .from('distributor_ocr_products')
        .select('*, views')
        .eq('distributor_id', userId);

    // جلب تفاصيل المنتجات العادية
    final productIds = rows.map((row) => row['product_id'].toString()).toSet().toList();
    final productDocs = await _supabase.from('products').select().inFilter('id', productIds);
    final productsMap = {
      for (var doc in productDocs)
        doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
    };

    // جلب تفاصيل منتجات OCR
    final ocrProductIds = ocrRows.map((row) => row['ocr_product_id'] as String).toSet().toList();
    final ocrProductDocs = await _supabase.from('ocr_products').select().inFilter('id', ocrProductIds);
    final ocrProductsMap = {
      for (var doc in ocrProductDocs)
        doc['id'].toString(): ProductModel(
          id: doc['id']?.toString() ?? '',
          name: doc['product_name']?.toString() ?? '',
          description: '',
          activePrinciple: doc['active_principle']?.toString(),
          company: doc['product_company']?.toString(),
          action: '',
          package: doc['package']?.toString() ?? '',
          imageUrl: (doc['image_url']?.toString() ?? '').startsWith('http') ? doc['image_url'].toString() : '',
          price: null,
          distributorId: doc['distributor_name']?.toString(),
          createdAt: doc['created_at'] != null ? DateTime.tryParse(doc['created_at'].toString()) : null,
          availablePackages: [doc['package']?.toString() ?? ''],
          selectedPackage: doc['package']?.toString() ?? '',
          isFavorite: false,
          oldPrice: null,
          priceUpdatedAt: null,
        )
    };

    final items = <ExpireDrugItem>[];

    // من المنتجات العادية
    for (final row in rows) {
      if (row['expiration_date'] != null) {
        final productDetails = productsMap[row['product_id'].toString()];
        if (productDetails != null) {
          DateTime? expirationDate;
          final exp = row['expiration_date'];
          if (exp is String) {
            expirationDate = DateTime.tryParse(exp);
          } else if (exp is DateTime) {
            expirationDate = exp;
          }
          items.add(ExpireDrugItem(
            product: productDetails.copyWith(
              price: (row['price'] as num?)?.toDouble(),
              selectedPackage: row['package'] as String?,
              distributorId: row['distributor_name'] as String?,
              views: (row['views'] as int?) ?? 0,
            ),
            expirationDate: expirationDate,
            isOcr: false,
          ));
        }
      }
    }

    // من منتجات OCR
    for (final row in ocrRows) {
      if (row['expiration_date'] != null) {
        final productDetails = ocrProductsMap[row['ocr_product_id']];
        if (productDetails != null) {
          DateTime? expirationDate;
          final exp = row['expiration_date'];
          if (exp is String) {
            expirationDate = DateTime.tryParse(exp);
          } else if (exp is DateTime) {
            expirationDate = exp;
          }
          final selectedPackage = row.containsKey('package') && row['package'] != null && (row['package'] as String).isNotEmpty
              ? row['package'] as String
              : (productDetails.selectedPackage ?? '');
          items.add(ExpireDrugItem(
            product: productDetails.copyWith(
              price: (row['price'] as num?)?.toDouble(),
              selectedPackage: selectedPackage,
              distributorId: row['distributor_name'] as String?,
              views: (row['views'] as int?) ?? 0,
            ),
            expirationDate: expirationDate,
            isOcr: true,
          ));
        }
      }
    }

    // Cache as JSON
    final jsonList = items.map((item) => item.toJson()).toList();
    _cache.set('my_expire_drugs_$userId', jsonList, duration: CacheDurations.medium);

    return items;
  }

  /// حذف كاش المنتجات منتهية الصلاحية
  void invalidateExpireDrugsCache() {
    _cache.invalidate('all_expire_drugs');
    _cache.invalidateWithPrefix('my_expire_drugs_');
    print('🧹 Expire drugs cache invalidated');
  }
}

// Provider
final expireDrugsRepositoryProvider = Provider<ExpireDrugsRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return ExpireDrugsRepository(cache);
});
