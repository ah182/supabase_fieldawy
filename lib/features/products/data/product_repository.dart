import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';



// Provider to track when product data was last modified
final productDataLastModifiedProvider = StateProvider<DateTime>((ref) {
  return DateTime.fromMicrosecondsSinceEpoch(0); // Initialize to epoch
});

class ProductRepository {
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
    final response = await _supabase
        .from('distributor_products')
        .select()
        .not('old_price', 'is', null)
        .order('price_updated_at', ascending: false);

    if (response.isEmpty) {
      return [];
    }

    final productIds =
        response.map((row) => row['product_id'] as String).toSet().toList();

    final productDocs =
        await _supabase.from('products').select().inFilter('id', productIds);

    final productsMap = {
      for (var doc in productDocs)
        doc['id'].toString(): ProductModel.fromMap(doc)
    };

    final products = response.map((row) {
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
    }).whereType<ProductModel>().toList();

    return products;
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
          .select('product_id, price, old_price, price_updated_at, package, distributor_name');

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
      final products = distProductsResponse.map((row) {
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
      }).whereType<ProductModel>().toList();
      
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
    required Map<String, double> productsToAdd,
  }) async {
    final rows = productsToAdd.entries.map((entry) {
      final parts = entry.key.split('_');
      final productId = parts[0];
      final package = parts.sublist(1).join('_');

      return {
        'id': '${distributorId}_${entry.key}',
        'distributor_id': distributorId,
        'distributor_name': distributorName,
        'product_id': productId,
        'package': package,
        'price': entry.value,
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

  Future<void> removeMultipleProductsFromDistributorCatalog({
    required String distributorId,
    required List<String> productIdsWithPackage,
  }) async {
    try {
      final List<String> docIdsToDelete = productIdsWithPackage.map((idWithPackage) {
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

  Future<String?> addOcrProduct({
    required String distributorId,
    required String distributorName,
    required String productName,
    required String productCompany,
    required String activePrinciple,
    required String package,
    required String imageUrl,
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
  }) async {
    await _supabase.from('distributor_ocr_products').insert({
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'ocr_product_id': ocrProductId,
      'price': price,
    });
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

  final products = rows.map((row) {
    final productDetails = productsMap[row['product_id']];
    if (productDetails != null) {
      return productDetails.copyWith(
        price: (row['price'] as num?)?.toDouble(),
        selectedPackage: row['package'] as String?,
        distributorId: row['distributor_name'] as String?,
      );
    }
    return null;
  }).whereType<ProductModel>().toList();

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

  final products = rows.map((row) {
    final productDetails = productsMap[row['product_id']];
    if (productDetails != null) {
      return productDetails.copyWith(
        price: (row['price'] as num?)?.toDouble(),
        selectedPackage: row['package'] as String?,
        distributorId: row['distributor_name'] as String?,
      );
    }
    return null;
  }).whereType<ProductModel>().toList();

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

final adminAllProductsProvider =
    FutureProvider<List<ProductModel>>((ref) {
  // This provider is for the admin panel and bypasses the cache to ensure
  // data is always fresh.
  ref.watch(productDataLastModifiedProvider);
  return ref
      .watch(productRepositoryProvider)
      .getAllDistributorProducts(bypassCache: true);
});