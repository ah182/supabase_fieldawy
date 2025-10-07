import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/domain/offer_model.dart';

import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';

// Provider to track when product data was last modified
final productDataLastModifiedProvider = StateProvider<DateTime>((ref) {
  return DateTime.fromMicrosecondsSinceEpoch(0); // Initialize to epoch
});

class ProductRepository {
  Future<void> updateProductExpirationAndPrice({
    required String distributorId,
    required String productId,
    required String package,
    required double newPrice,
    required DateTime? expirationDate,
  }) async {
    // استخدم match بدلاً من id فقط لدعم product_id النصي أو أي قيمة
    final Map<String, Object> matchMap = {
      'distributor_id': distributorId,
      'product_id': productId,
      if (package.isNotEmpty) 'package': package,
    };
    final response = await _supabase
        .from('distributor_products')
        .select('price')
        .match(matchMap)
        .maybeSingle();
    final oldPrice = (response != null && response['price'] != null) ? (response['price'] as num?)?.toDouble() : null;
    await _supabase.from('distributor_products').update({
      'price': newPrice,
      'old_price': oldPrice,
      'price_updated_at': DateTime.now().toIso8601String(),
      'expiration_date': expirationDate?.toIso8601String(),
    }).match(matchMap);
    _scheduleCacheInvalidation();
  }

  Future<void> updateOcrProductExpirationAndPrice({
    required String distributorId,
    required String ocrProductId,
    required double newPrice,
    required DateTime? expirationDate,
  }) async {
    await _supabase.from('distributor_ocr_products').update({
      'price': newPrice,
      'expiration_date': expirationDate?.toIso8601String(),
    }).match({
      'distributor_id': distributorId,
      'ocr_product_id': ocrProductId,
    });
    _scheduleCacheInvalidation();
  }
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;
  late final Ref _ref;
  static Timer? _invalidationTimer;

  ProductRepository({required CachingService cache, required Ref ref})
      : _cache = cache,
        _ref = ref;

  Future<List<String>> getAllDistributorProductIds() async {
    final rows = await _supabase.from('distributor_products').select('id');
    return rows.map((row) => row['id'] as String).toList();
  }

  Future<List<ProductModel>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final rows = await _supabase
        .from('distributor_products')
        .select()
        .inFilter('id', ids);

    if (rows.isEmpty) {
      return [];
    }

    final distributorProductDetailsMap = {
      for (var row in rows) row['id'].toString(): row
    };

    final productIds =
        rows.map((row) => row['product_id'] as String).toSet().toList();

    final productDocs =
        await _supabase.from('products').select().inFilter('id', productIds);

    final productsMap = {
      for (var doc in productDocs)
        doc['id'].toString(): ProductModel.fromMap(doc)
    };

    final List<ProductModel> orderedProducts = [];
    for (final id in ids) {
      final distributorProductRow = distributorProductDetailsMap[id];
      if (distributorProductRow != null) {
        final productDetails = productsMap[distributorProductRow['product_id']];
        if (productDetails != null) {
          orderedProducts.add(productDetails.copyWith(
            price: (distributorProductRow['price'] as num?)?.toDouble(),
            oldPrice: (distributorProductRow['old_price'] as num?)?.toDouble(),
            priceUpdatedAt: distributorProductRow['price_updated_at'] != null
                ? DateTime.tryParse(distributorProductRow['price_updated_at'])
                : null,
            selectedPackage: distributorProductRow['package'] as String?,
            distributorId: distributorProductRow['distributor_name'] as String?,
          ));
        }
      }
    }

    return orderedProducts;
  }

  Future<List<ProductModel>> getProductsWithPriceUpdates() async {
    // جلب المنتجات العادية من الكتالوج
    final response = await _supabase
        .from('distributor_products')
        .select()
        .not('old_price', 'is', null)
        .order('price_updated_at', ascending: false);

    final productIds =
        response.map((row) => row['product_id'] as String).toSet().toList();

    List<ProductModel> catalogProducts = [];
    if (productIds.isNotEmpty) {
      final productDocs =
          await _supabase.from('products').select().inFilter('id', productIds);

      final productsMap = {
        for (var doc in productDocs)
          doc['id'].toString(): ProductModel.fromMap(doc)
      };

      catalogProducts = response
          .map((row) {
            final productDetails = productsMap[row['product_id']];
            if (productDetails != null) {
              return productDetails.copyWith(
                price: (row['price'] as num?)?.toDouble(),
                oldPrice: (row['old_price'] as num?)?.toDouble(),
                priceUpdatedAt: row['price_updated_at'] != null
                    ? DateTime.tryParse(row['price_updated_at'])
                    : null,
                selectedPackage: row['package'] as String?,
                distributorId: row['distributor_name'] as String?,
              );
            }
            return null;
          })
          .whereType<ProductModel>()
          .toList();
    }

    // جلب منتجات OCR التي تغير سعرها
    final ocrResponse = await _supabase
        .from('distributor_ocr_products')
        .select()
        .not('old_price', 'is', null)
        .order('price_updated_at', ascending: false);

    final ocrProductIds = ocrResponse
        .map((row) => row['ocr_product_id'] as String)
        .toSet()
        .toList();

    List<ProductModel> ocrProducts = [];
    if (ocrProductIds.isNotEmpty) {
      final ocrProductDocs = await _supabase
          .from('ocr_products')
          .select()
          .inFilter('id', ocrProductIds);

      final ocrProductsMap = <String, Map<String, dynamic>>{
        for (var doc in ocrProductDocs) doc['id'].toString(): doc
      };

      // جلب أسماء الموزعين
      final distributorIds = ocrResponse
          .map((row) => row['distributor_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> distributorNames = {};
      if (distributorIds.isNotEmpty) {
        final usersData = await _supabase
            .from('users')
            .select('id, display_name')
            .inFilter('id', distributorIds);

        for (final user in usersData) {
          distributorNames[user['id'].toString()] =
              user['display_name']?.toString() ?? 'موزع غير معروف';
        }
      }

      ocrProducts = ocrResponse
          .map((row) {
            final ocrProductDoc = ocrProductsMap[row['ocr_product_id']];
            if (ocrProductDoc != null) {
              final distributorName =
                  distributorNames[row['distributor_id']] ?? 'موزع غير معروف';
              return ProductModel(
                id: ocrProductDoc['id']?.toString() ?? '',
                name: ocrProductDoc['product_name']?.toString() ?? '',
                description: ocrProductDoc['description']?.toString(),
                activePrinciple: ocrProductDoc['active_principle']?.toString(),
                company: ocrProductDoc['product_company']?.toString(),
                action: '',
                package: ocrProductDoc['package']?.toString() ?? '',
                imageUrl:
                    (ocrProductDoc['image_url']?.toString() ?? '').startsWith('http')
                        ? ocrProductDoc['image_url'].toString()
                        : '',
                price: (row['price'] as num?)?.toDouble(),
                oldPrice: (row['old_price'] as num?)?.toDouble(),
                priceUpdatedAt: row['price_updated_at'] != null
                    ? DateTime.tryParse(row['price_updated_at'])
                    : null,
                distributorId: distributorName,
                createdAt: row['created_at'] != null
                    ? DateTime.tryParse(row['created_at'].toString())
                    : null,
                availablePackages: [ocrProductDoc['package']?.toString() ?? ''],
                selectedPackage: ocrProductDoc['package']?.toString() ?? '',
                isFavorite: false,
              );
            }
            return null;
          })
          .whereType<ProductModel>()
          .toList();
    }

    // دمج القائمتين وترتيبهم حسب تاريخ تحديث السعر
    final allProducts = [...catalogProducts, ...ocrProducts];
    allProducts.sort((a, b) {
      if (a.priceUpdatedAt == null && b.priceUpdatedAt == null) return 0;
      if (a.priceUpdatedAt == null) return 1;
      if (b.priceUpdatedAt == null) return -1;
      return b.priceUpdatedAt!.compareTo(a.priceUpdatedAt!);
    });

    return allProducts;
  }

  Future<List<ProductModel>> getAllProducts() async {
    const cacheKey = 'all_products_catalog';
    final cachedData = _cache.get<List<dynamic>>(cacheKey);
    if (cachedData != null) {
      _refreshAllProductsInBackground();
      return cachedData.map((item) => item as ProductModel).toList();
    }
    return _fetchAllProductsFromServer();
  }

  Future<List<ProductModel>> _fetchAllProductsFromServer() async {
    const cacheKey = 'all_products_catalog';
    try {
      final response = await _supabase.functions.invoke('get-products');

      if (response.data == null) {
        throw Exception('Function get-products returned null data');
      }

      final List<dynamic> responseData = response.data;
      final products = responseData
          .map((row) => ProductModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      _cache.set(cacheKey, products, duration: const Duration(days: 365));

      return products;
    } catch (e) {
      print('Error fetching products from server: $e');
      return [];
    }
  }

  void _refreshAllProductsInBackground() {
    _fetchAllProductsFromServer().catchError((e) {
      print('Background product refresh failed: $e');
      return <ProductModel>[];
    });
  }

  Future<List<ProductModel>> getAllDistributorProducts(
      {bool bypassCache = false}) async {
    const cacheKey = 'all_distributor_products';
    if (!bypassCache) {
      final cachedData = _cache.get<List<dynamic>>(cacheKey);
      if (cachedData != null) {
        _refreshAllDistributorProductsInBackground();
        return cachedData.map((item) => item as ProductModel).toList();
      }
    }
    return _fetchAllDistributorProductsFromServer();
  }

  Future<List<ProductModel>> _fetchAllDistributorProductsFromServer() async {
    const cacheKey = 'all_distributor_products';
    try {
      // 1. Fetch all rows from distributor_products, explicitly selecting columns
      final distProductsResponse = await _supabase
          .from('distributor_products')
          .select(
              'product_id, price, old_price, price_updated_at, package, distributor_name');

      if (distProductsResponse.isEmpty) {
        return [];
      }

      // 2. Get unique product IDs
      final productIds = distProductsResponse
          .map((row) => row['product_id'] as String)
          .toSet()
          .toList();

      // 3. Fetch the corresponding products from the main products table
      final productDocs =
          await _supabase.from('products').select().inFilter('id', productIds);

      // 4. Create a lookup map for main product details
      final productsMap = {
        for (var doc in productDocs)
          doc['id'].toString(): ProductModel.fromMap(doc)
      };

      // 5. Join the data
      final products = distProductsResponse
          .map((row) {
            final productDetails = productsMap[row['product_id']];
            if (productDetails != null) {
              return productDetails.copyWith(
                // Overwrite with distributor-specific data
                price: (row['price'] as num?)?.toDouble(),
                oldPrice: (row['old_price'] as num?)?.toDouble(),
                priceUpdatedAt: row['price_updated_at'] != null
                    ? DateTime.tryParse(row['price_updated_at'])
                    : null,
                selectedPackage: row['package'] as String?,
                distributorId: row['distributor_name'] as String?,
              );
            }
            return null;
          })
          .whereType<ProductModel>()
          .toList();

      _cache.set(cacheKey, products, duration: const Duration(minutes: 30));

      return products;
    } catch (e) {
      print('Error fetching all distributor products from server: $e');
      return [];
    }
  }

  void _refreshAllDistributorProductsInBackground() {
    _fetchAllDistributorProductsFromServer().catchError((e) {
      print('Background distributor product refresh failed: $e');
      return <ProductModel>[];
    });
  }

  Future<void> addMultipleProductsToDistributorCatalog({
    required String distributorId,
    required String distributorName,
    required Map<String, Map<String, dynamic>> productsToAdd,
  }) async {
    final rows = productsToAdd.entries.map((entry) {
      final parts = entry.key.split('_');
      final productId = parts[0];
      final package = parts.sublist(1).join('_');
      final productData = entry.value;

      return {
        'id': '${distributorId}_${entry.key}',
        'distributor_id': distributorId,
        'distributor_name': distributorName,
        'product_id': productId,
        'package': package,
        'price': productData['price'],
        'expiration_date': productData['expiration_date'],
        'added_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _supabase.from('distributor_products').upsert(rows);

    _scheduleCacheInvalidation();
  }

  Future<void> removeProductFromDistributorCatalog({
    required String distributorId,
    required String productId,
    required String package,
  }) async {
    final docId = '${distributorId}_${productId}_$package';
    await _supabase.from('distributor_products').delete().eq('id', docId);

    _scheduleCacheInvalidation();
  }

  Future<void> removeOcrProductFromDistributorCatalog({
    required String distributorId,
    required String ocrProductId,
  }) async {
    await _supabase.from('distributor_ocr_products').delete().match({
      'distributor_id': distributorId,
      'ocr_product_id': ocrProductId,
    });

    _scheduleCacheInvalidation();
  }

  Future<void> removeMultipleProductsFromDistributorCatalog({
    required String distributorId,
    required List<String> productIdsWithPackage,
  }) async {
    try {
      final List<String> docIdsToDelete =
          productIdsWithPackage.map((idWithPackage) {
        return "${distributorId}_$idWithPackage";
      }).toList();

      await _supabase
          .from('distributor_products')
          .delete()
          .inFilter('id', docIdsToDelete);

      _scheduleCacheInvalidation();
    } catch (e) {
      print('Error deleting multiple products from distributor catalog: $e');
      rethrow;
    }
  }

  Future<void> removeMultipleOcrProductsFromDistributorCatalog({
    required String distributorId,
    required List<String> ocrProductIds,
  }) async {
    try {
      await _supabase
          .from('distributor_ocr_products')
          .delete()
          .match({'distributor_id': distributorId})
          .inFilter('ocr_product_id', ocrProductIds);

      _scheduleCacheInvalidation();
    } catch (e) {
      print('Error deleting multiple OCR products from distributor catalog: $e');
      rethrow;
    }
  }

  Future<String?> addOcrProduct({
    required String distributorId,
    required String distributorName,
    required String productName,
    required String productCompany,
    required String activePrinciple,
    required String package,
    String imageUrl = '',
  }) async {
    final response = await _supabase.from('ocr_products').insert({
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'product_name': productName,
      'product_company': productCompany,
      'active_principle': activePrinciple,
      'package': package,
      'image_url': imageUrl,
    }).select();
    if (response.isNotEmpty) {
      return response.first['id'].toString();
    }
    return null;
  }

  Future<void> addDistributorOcrProduct({
    required String distributorId,
    required String distributorName,
    required String ocrProductId,
    required double price,
    DateTime? expirationDate,
  }) async {
    final response = await _supabase.from('distributor_ocr_products').insert({
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'ocr_product_id': ocrProductId,
      'price': price,
      'expiration_date': expirationDate?.toIso8601String(),
    }).select();
    print(
        'DEBUG: distributor_ocr_products insert response: \u001b[36m$response\u001b[0m');
  }

  Future<void> addMultipleDistributorOcrProducts({
    required String distributorId,
    required String distributorName,
    required List<Map<String, dynamic>> ocrProducts, // List of {ocrProductId: String, price: double}
  }) async {
    final rows = ocrProducts.map((product) {
      return {
        'distributor_id': distributorId,
        'distributor_name': distributorName,
        'ocr_product_id': product['ocrProductId'] as String,
        'price': product['price'] as double,
        'expiration_date': product['expiration_date'],
      };
    }).toList();

    await _supabase.from('distributor_ocr_products').upsert(rows, onConflict: 'distributor_id,ocr_product_id');
  }

  Future<List<ProductModel>> getOcrProducts() async {
    try {
      // Fetch all OCR products from the ocr_products table
      final ocrProductsResponse = await _supabase
          .from('ocr_products')
          .select('*')
          .order('created_at', ascending: false);

      if (ocrProductsResponse.isEmpty) {
        return [];
      }

      // Convert OCR products to ProductModel instances
      final ocrProducts = ocrProductsResponse.map((row) {
        // Map OCR product fields to ProductModel
        String imageUrl = row['image_url']?.toString() ?? '';

        // Validate and fix image URL if needed
        if (imageUrl.isNotEmpty) {
          // Check if the URL starts with http/https
          if (!imageUrl.startsWith('http://') &&
              !imageUrl.startsWith('https://')) {
            // If it's not a proper URL format, set as empty to use placeholder
            imageUrl = '';
          }
        } else {
          imageUrl = '';
        }

        return ProductModel(
          id: row['id']?.toString() ?? '',
          name: row['product_name']?.toString() ?? '',
          description: '', // OCR products don't have description in the schema
          activePrinciple: row['active_principle']?.toString(),
          company: row['product_company']?.toString(),
          action: '', // OCR products don't have action in the schema
          package: row['package']?.toString() ?? '',
          imageUrl: imageUrl,
          price: null, // OCR products don't have price in main table
          distributorId: row['distributor_name']?.toString(),
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null,
          availablePackages: [
            row['package']?.toString() ?? ''
          ], // Single package from OCR
          selectedPackage: row['package']?.toString() ?? '',
        );
      }).toList();

      return ocrProducts;
    } catch (e) {
      print('Error fetching OCR products: $e');
      return [];
    }
  }

  Future<List<ProductModel>> getMyOcrProducts(String distributorId) async {
    try {
      // Fetch distributor OCR products for this specific distributor
      final distributorOcrResponse = await _supabase
          .from('distributor_ocr_products')
          .select('ocr_product_id, price, created_at')
          .eq('distributor_id', distributorId)
          .order('created_at', ascending: false);

      if (distributorOcrResponse.isEmpty) {
        return [];
      }

      // Get unique OCR product IDs
      final ocrProductIds = distributorOcrResponse
          .map((row) => row['ocr_product_id'] as String)
          .toList();

      // Fetch the corresponding OCR products
      final ocrProductsResponse = await _supabase
          .from('ocr_products')
          .select('*')
          .inFilter('id', ocrProductIds);

      if (ocrProductsResponse.isEmpty) {
        return [];
      }

      // Create a map of OCR products for quick lookup
      final ocrProductsMap = {
        for (var row in ocrProductsResponse) row['id'].toString(): row
      };

      // Join the data
      final products = distributorOcrResponse
          .map((distRow) {
            final ocrProduct = ocrProductsMap[distRow['ocr_product_id']];
            if (ocrProduct != null) {
              String imageUrl = ocrProduct['image_url']?.toString() ?? '';

              // Validate and fix image URL if needed
              if (imageUrl.isNotEmpty) {
                if (!imageUrl.startsWith('http://') &&
                    !imageUrl.startsWith('https://')) {
                  imageUrl = '';
                }
              }

              return ProductModel(
                id: ocrProduct['id']?.toString() ?? '',
                name: ocrProduct['product_name']?.toString() ?? '',
                description: '',
                activePrinciple: ocrProduct['active_principle']?.toString(),
                company: ocrProduct['product_company']?.toString(),
                action: '',
                package: ocrProduct['package']?.toString() ?? '',
                imageUrl: imageUrl,
                price: (distRow['price'] as num?)?.toDouble(),
                distributorId: ocrProduct['distributor_name']?.toString(),
                createdAt: distRow['created_at'] != null
                    ? DateTime.tryParse(distRow['created_at'].toString())
                    : null,
                availablePackages: [ocrProduct['package']?.toString() ?? ''],
                selectedPackage: ocrProduct['package']?.toString() ?? '',
              );
            }
            return null;
          })
          .whereType<ProductModel>()
          .toList();

      return products;
    } catch (e) {
      print('Error fetching my OCR products: $e');
      return [];
    }
  }

  Future<String?> addProductToCatalog(ProductModel product) async {
    final response =
        await _supabase.from('products').insert(product.toMap()).select();
    if (response.isNotEmpty) {
      _scheduleCacheInvalidation();
      return response.first['id'].toString();
    }
    return null;
  }

  Future<void> addProductToDistributorCatalog({
    required String distributorId,
    required String distributorName,
    required String productId,
    required String package,
    required double price,
  }) async {
    final docId = '${distributorId}_${productId}_$package';
    await _supabase.from('distributor_products').upsert({
      'id': docId,
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'product_id': productId,
      'package': package,
      'price': price,
      'added_at': DateTime.now().toIso8601String(),
    });

    _scheduleCacheInvalidation();
  }

  Future<void> updateProductPriceInDistributorCatalog({
    required String distributorId,
    required String productId,
    required String package,
    required double newPrice,
  }) async {
    final docId = '${distributorId}_${productId}_$package';

    final response = await _supabase
        .from('distributor_products')
        .select('price')
        .eq('id', docId)
        .single();

    final oldPrice = (response['price'] as num?)?.toDouble();

    await _supabase.from('distributor_products').update({
      'price': newPrice,
      'old_price': oldPrice,
      'price_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', docId);

    _scheduleCacheInvalidation();
  }

  Future<void> updateOcrProductPrice({
    required String distributorId,
    required String ocrProductId,
    required double newPrice,
  }) async {
    // جلب السعر القديم أولاً
    final response = await _supabase
        .from('distributor_ocr_products')
        .select('price')
        .match({
          'distributor_id': distributorId,
          'ocr_product_id': ocrProductId,
        })
        .maybeSingle();

    final oldPrice = (response?['price'] as num?)?.toDouble();

    // تحديث السعر الجديد مع حفظ السعر القديم وتاريخ التحديث
    await _supabase.from('distributor_ocr_products').update({
      'price': newPrice,
      'old_price': oldPrice,
      'price_updated_at': DateTime.now().toIso8601String(),
    }).match({
      'distributor_id': distributorId,
      'ocr_product_id': ocrProductId,
    });

    _scheduleCacheInvalidation();
  }

  void _scheduleCacheInvalidation() {
    final now = DateTime.now();
    _ref.read(productDataLastModifiedProvider.notifier).state = now;

    _invalidationTimer?.cancel();

    _invalidationTimer = Timer(const Duration(milliseconds: 100), () {
      try {
        _cache.invalidateWithPrefix('distributor_products_');
        _cache.invalidate('allDistributorProducts');
        _cache.invalidateWithPrefix('my_products_');
      } catch (e) {
        print('Error during cache invalidation: $e');
      }
    });
  }

  // ========== Offers Methods ==========
  
  Future<String?> addOffer({
    required String productId,
    required bool isOcr,
    required String userId,
    required double price,
    required DateTime expirationDate,
    String? description,
    String? package,
  }) async {
    final response = await _supabase.from('offers').insert({
      'product_id': productId,
      'is_ocr': isOcr,
      'user_id': userId,
      'price': price,
      'expiration_date': expirationDate.toIso8601String(),
      'description': description,
      'package': package,
    }).select();
    
    if (response.isNotEmpty) {
      return response.first['id'].toString();
    }
    return null;
  }

  Future<void> updateOfferDescription({
    required String offerId,
    required String description,
  }) async {
    await _supabase.from('offers').update({
      'description': description,
    }).eq('id', offerId);
  }

  Future<void> updateOffer({
    required String offerId,
    required String description,
    required double price,
    required DateTime expirationDate,
  }) async {
    await _supabase.from('offers').update({
      'description': description,
      'price': price,
      'expiration_date': expirationDate.toIso8601String(),
    }).eq('id', offerId);
  }

  Future<List<OfferModel>> getMyOffers(String userId) async {
    try {
      final response = await _supabase
          .from('offers')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((row) => OfferModel.fromMap(row)).toList();
    } catch (e) {
      print('Error fetching offers: $e');
      return [];
    }
  }

  Future<void> deleteOffer(String offerId) async {
    await _supabase.from('offers').delete().eq('id', offerId);
  }

  // حذف العروض القديمة (أكثر من 7 أيام من تاريخ الإنشاء)
  Future<void> deleteExpiredOffers() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      await _supabase
          .from('offers')
          .delete()
          .lt('created_at', sevenDaysAgo.toIso8601String());
      print('Deleted offers created before: $sevenDaysAgo');
    } catch (e) {
      print('Error deleting expired offers: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyOffersWithProducts(String userId) async {
    try {
      // حذف العروض المنتهية منذ أكثر من 7 أيام قبل جلب القائمة
      await deleteExpiredOffers();
      
      final offers = await _supabase
          .from('offers')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('📋 Found ${offers.length} offers for user: $userId');

      final List<Map<String, dynamic>> offersWithProducts = [];

      for (var offer in offers) {
        final isOcr = offer['is_ocr'] as bool;
        final productId = offer['product_id'] as String;
        
        print('🔍 Processing offer: id=${offer['id']}, is_ocr=$isOcr, product_id=$productId');

        Map<String, dynamic>? productData;

        if (isOcr) {
          // جلب من ocr_products
          final ocrProduct = await _supabase
              .from('ocr_products')
              .select()
              .eq('id', productId)
              .maybeSingle();
          
          if (ocrProduct != null) {
            productData = {
              'id': ocrProduct['id'],
              'name': ocrProduct['product_name'],
              'company': ocrProduct['product_company'] ?? '',
              'package': ocrProduct['package'] ?? '',
              'imageUrl': ocrProduct['image_url'] ?? '',
            };
            
            print('OCR Product Data: name=${ocrProduct['product_name']}, company=${ocrProduct['product_company']}, package=${ocrProduct['package']}');
          }
        } else {
          // جلب بيانات المنتج من products
          print('🔎 Fetching from products table with id: $productId');
          
          final product = await _supabase
              .from('products')
              .select('id, name, company, image_url')
              .eq('id', productId)
              .maybeSingle();
          
          print('📦 Product result: $product');
          
          if (product != null) {
            // جلب الباكدج من جدول offers نفسه (الباكدج التي اختارها المستخدم عند إنشاء العرض)
            final packageName = (offer['package'] as String?) ?? '';
            
            print('📦 Package from offer: $packageName');
            
            productData = {
              'id': product['id'],
              'name': product['name'] ?? '',
              'company': product['company'] ?? '',
              'package': packageName,
              'imageUrl': product['image_url'] ?? '',
            };
            
            print('✅ Final Product Data: name=${product['name']}, company=${product['company']}, package=$packageName');
          } else {
            print('❌ Product not found in products table for id: $productId');
          }
        }

        if (productData != null) {
          offersWithProducts.add({
            'offer': offer,
            'product': productData,
          });
          print('✅ Added offer with product: ${productData['name']}');
        } else {
          print('⚠️ Skipping offer ${offer['id']} - product data is null');
        }
      }

      print('📊 Total offers with products: ${offersWithProducts.length}');
      return offersWithProducts;
    } catch (e) {
      print('Error fetching offers with products: $e');
      return [];
    }
  }

  // ============================================
  // Surgical Tools Methods
  // ============================================

  /// إضافة أداة جراحية جديدة للكتالوج العام
  Future<String?> addSurgicalTool({
    required String toolName,
    String? company,
    String? imageUrl,
    required String createdBy,
  }) async {
    try {
      final response = await _supabase.from('surgical_tools').insert({
        'tool_name': toolName,
        if (company != null && company.isNotEmpty) 'company': company,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'created_by': createdBy,
      }).select('id').single();

      return response['id'] as String?;
    } catch (e) {
      print('Error adding surgical tool: $e');
      return null;
    }
  }

  /// ربط أداة جراحية بالموزع (مع السعر والوصف الخاص به)
  Future<bool> addDistributorSurgicalTool({
    required String distributorId,
    required String distributorName,
    required String surgicalToolId,
    required String description,
    required double price,
    String status = 'جديد',
  }) async {
    try {
      await _supabase.from('distributor_surgical_tools').insert({
        'distributor_id': distributorId,
        'distributor_name': distributorName,
        'surgical_tool_id': surgicalToolId,
        'description': description,
        'price': price,
        'status': status,
      });

      _scheduleCacheInvalidation();
      return true;
    } catch (e) {
      print('Error adding distributor surgical tool: $e');
      return false;
    }
  }

  /// جلب أدوات موزع معين
  Future<List<Map<String, dynamic>>> getMySurgicalTools(String distributorId) async {
    try {
      final response = await _supabase
          .from('distributor_surgical_tools')
          .select('''
            id,
            description,
            price,
            status,
            created_at,
            surgical_tools (
              id,
              tool_name,
              company,
              image_url
            )
          ''')
          .eq('distributor_id', distributorId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching my surgical tools: $e');
      return [];
    }
  }

  /// البحث في الأدوات الجراحية
  Future<List<Map<String, dynamic>>> searchSurgicalTools(String searchQuery) async {
    try {
      final response = await _supabase.rpc('search_surgical_tools', params: {
        'search_query': searchQuery,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching surgical tools: $e');
      return [];
    }
  }

  /// تحديث أداة جراحية للموزع
  Future<bool> updateDistributorSurgicalTool({
    required String id,
    String? description,
    double? price,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (description != null) updates['description'] = description;
      if (price != null) updates['price'] = price;
      if (status != null) updates['status'] = status;

      if (updates.isEmpty) return false;

      await _supabase
          .from('distributor_surgical_tools')
          .update(updates)
          .eq('id', id);

      _scheduleCacheInvalidation();
      return true;
    } catch (e) {
      print('Error updating distributor surgical tool: $e');
      return false;
    }
  }

  /// حذف أداة جراحية للموزع
  Future<bool> deleteDistributorSurgicalTool(String id) async {
    try {
      await _supabase
          .from('distributor_surgical_tools')
          .delete()
          .eq('id', id);

      _scheduleCacheInvalidation();
      return true;
    } catch (e) {
      print('Error deleting distributor surgical tool: $e');
      return false;
    }
  }

  /// جلب جميع الأدوات الجراحية من جميع الموزعين
  Future<List<Map<String, dynamic>>> getAllSurgicalTools() async {
    try {
      final response = await _supabase
          .from('distributor_surgical_tools')
          .select('''
            id,
            description,
            price,
            status,
            distributor_name,
            distributor_id,
            created_at,
            surgical_tools (
              id,
              tool_name,
              company,
              image_url
            )
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all surgical tools: $e');
      return [];
    }
  }

  /// جلب كتالوج الأدوات الجراحية (من جدول surgical_tools)
  Future<List<Map<String, dynamic>>> getSurgicalToolsCatalog() async {
    try {
      final response = await _supabase
          .from('surgical_tools')
          .select('id, tool_name, company, image_url, created_at')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching surgical tools catalog: $e');
      return [];
    }
  }

  /// إضافة أداة جراحية من الكتالوج إلى مخزون الموزع
  Future<void> addToolToInventory({
    required String userId,
    required String toolId,
    required String description,
    required double price,
    required String status,
  }) async {
    try {
      // جلب معلومات المستخدم للحصول على الاسم
      final userResponse = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();

      final distributorName = userResponse?['display_name'] ?? 'Unknown';

      await _supabase.from('distributor_surgical_tools').insert({
        'distributor_id': userId,
        'surgical_tool_id': toolId,
        'description': description,
        'price': price,
        'status': status,
        'distributor_name': distributorName,
        'created_at': DateTime.now().toIso8601String(),
      });

      _scheduleCacheInvalidation();
    } catch (e) {
      print('Error adding tool to inventory: $e');
      rethrow;
    }
  }
}

// --- Providers ---
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final cachingService = ref.watch(cachingServiceProvider);
  return ProductRepository(cache: cachingService, ref: ref);
});

final priceUpdatesProvider = FutureProvider<List<ProductModel>>((ref) {
  // By watching this provider, this FutureProvider will automatically re-run
  // whenever a product is added, removed, or updated.
  ref.watch(productDataLastModifiedProvider);
  return ref.watch(productRepositoryProvider).getProductsWithPriceUpdates();
});

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(productRepositoryProvider).getAllProducts();
});

final ocrProductsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(productRepositoryProvider).getOcrProducts();
});

final myOcrProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) return [];

  // جلب كل منتجات OCR الخاصة بالمستخدم
  final allOcrProducts =
      await ref.watch(productRepositoryProvider).getMyOcrProducts(userId);
  // فلترة المنتجات التي ليس لها expiration_date فقط
  final supabase = Supabase.instance.client;
  final distributorOcrRows = await supabase
      .from('distributor_ocr_products')
      .select('ocr_product_id, expiration_date')
      .eq('distributor_id', userId);
  final Map<String, dynamic> ocrIdToExpiration = {
    for (var row in distributorOcrRows)
      row['ocr_product_id']: row['expiration_date']
  };
  return allOcrProducts.where((product) {
    final exp = ocrIdToExpiration[product.id];
    return exp == null || (exp is String && exp.isEmpty);
  }).toList();
});

class PaginatedProductsState extends Equatable {
  final List<ProductModel> products;
  final bool isLoading;
  final bool hasMore;

  const PaginatedProductsState({
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [products, isLoading, hasMore];

  PaginatedProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? hasMore,
  }) {
    return PaginatedProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class PaginatedProductsNotifier extends StateNotifier<PaginatedProductsState> {
  final ProductRepository _repository;
  List<String> _shuffledIds = [];
  int _page = 0;
  static const int _pageSize = 10;

  PaginatedProductsNotifier(this._repository)
      : super(const PaginatedProductsState()) {
    refresh();
  }

  Future<void> fetchNextPage() async {
    if ((state.isLoading && _page > 0) || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final from = _page * _pageSize;
      if (from >= _shuffledIds.length) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      final to = min(from + _pageSize, _shuffledIds.length);
      final pageIds = _shuffledIds.sublist(from, to);

      final newProducts = await _repository.getProductsByIds(pageIds);

      if (newProducts.length < _pageSize || to == _shuffledIds.length) {
        state = state.copyWith(hasMore: false);
      }

      state = state.copyWith(
        products: [...state.products, ...newProducts],
        isLoading: false,
      );
      _page++;
    } catch (e) {
      print('fetchNextPage: ERROR: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = const PaginatedProductsState(isLoading: true);
    _page = 0;
    try {
      _shuffledIds = await _repository.getAllDistributorProductIds();
      _shuffledIds.shuffle();
      state = state.copyWith(products: []);
      await fetchNextPage();
    } catch (e) {
      print('refresh: ERROR: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final paginatedProductsProvider =
    StateNotifierProvider<PaginatedProductsNotifier, PaginatedProductsState>(
        (ref) {
  final repository = ref.watch(productRepositoryProvider);
  return PaginatedProductsNotifier(repository);
});

final internalAllProductsProvider =
    FutureProvider<List<ProductModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final rows = await supabase.from('distributor_products').select();
  if (rows.isEmpty) {
    return [];
  }

  final productIds =
      rows.map((row) => row['product_id'] as String).toSet().toList();

  final productDocs =
      await supabase.from('products').select().inFilter('id', productIds);

  final productsMap = {
    for (var doc in productDocs)
      doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
  };

  final products = rows
      .map((row) {
        final productDetails = productsMap[row['product_id']];
        if (productDetails != null) {
          return productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: row['package'] as String?,
            distributorId: row['distributor_name'] as String?,
          );
        }
        return null;
      })
      .whereType<ProductModel>()
      .toList();

  return products;
});

final myProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) return [];

  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  final lastModified = ref.watch(productDataLastModifiedProvider);
  final cacheKey = 'my_products_$userId';

  final timestampedCacheKey =
      '$cacheKey-${lastModified.microsecondsSinceEpoch}-$userId';

  final cachedData = cache.get<List<dynamic>>(timestampedCacheKey);
  if (cachedData != null) {
    // لا يمكن التأكد من expiration_date في الكاش مباشرة، لذا نعيد كل المنتجات
    // (الفلترة ستتم عند جلب البيانات من Supabase)
    return cachedData.map((item) => item as ProductModel).toList();
  }

  final rows = await supabase
      .from('distributor_products')
      .select()
      .eq('distributor_id', userId);

  if (rows.isEmpty) {
    cache.set(timestampedCacheKey, [], duration: const Duration(minutes: 20));
    return [];
  }

  final productIds =
      rows.map((row) => row['product_id'] as String).toSet().toList();

  final productDocs =
      await supabase.from('products').select().inFilter('id', productIds);

  final productsMap = {
    for (var doc in productDocs)
      doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
  };

  final products = rows
      .where((row) => row['expiration_date'] == null)
      .map((row) {
        final productDetails = productsMap[row['product_id']];
        if (productDetails != null) {
          return productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: row['package'] as String?,
            distributorId: row['distributor_name'] as String?,
          );
        }
        return null;
      })
      .whereType<ProductModel>()
      .toList();

  cache.set(timestampedCacheKey, products,
      duration: const Duration(minutes: 20));
  return products;
});

final allDistributorProductsProvider =
    FutureProvider<List<ProductModel>>((ref) {
  // This provider is for the user-facing app and uses caching.
  ref.watch(productDataLastModifiedProvider);
  return ref.watch(productRepositoryProvider).getAllDistributorProducts();
});

final adminAllProductsProvider = FutureProvider<List<ProductModel>>((ref) {
  // This provider is for the admin panel and bypasses the cache to ensure
  // data is always fresh.
  ref.watch(productDataLastModifiedProvider);
  return ref
      .watch(productRepositoryProvider)
      .getAllDistributorProducts(bypassCache: true);
});

final myOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  
  return ref.watch(productRepositoryProvider).getMyOffersWithProducts(userId);
});
