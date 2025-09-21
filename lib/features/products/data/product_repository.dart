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

    // Create a map for quick lookup of distributor product details by their ID
    final distributorProductDetailsMap = {
      for (var row in rows) row['id'].toString(): row
    };

    final productIds =
        rows.map((row) => row['product_id'] as String).toSet().toList();

    final productDocs =
        await _supabase.from('products').select().inFilter('id', productIds);

    // Create a map for quick lookup of main product details by their ID
    final productsMap = {
      for (var doc in productDocs)
        doc['id'].toString(): ProductModel.fromMap(doc)
    };

    // Build the final list of products in the *shuffled order* of the input 'ids'
    final List<ProductModel> orderedProducts = [];
    for (final id in ids) {
      // Iterate through the shuffled 'ids'
      final distributorProductRow = distributorProductDetailsMap[id];
      if (distributorProductRow != null) {
        final productDetails = productsMap[distributorProductRow['product_id']];
        if (productDetails != null) {
          orderedProducts.add(productDetails.copyWith(
            price: (distributorProductRow['price'] as num?)?.toDouble(),
            selectedPackage: distributorProductRow['package'] as String?,
            distributorId: distributorProductRow['distributor_name'] as String?,
          ));
        }
      }
    }

    return orderedProducts;
  }

  /// جلب كل المنتجات من الكتالوج الرئيسي
  Future<List<ProductModel>> getAllProducts() async {
    const cacheKey = 'all_products_catalog';
    
    // Try to get from cache first
    final cachedData = _cache.get<List<ProductModel>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      final rows = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);
      
      final products = rows.map((row) => ProductModel.fromMap(row)).toList();
      
      // Cache for 1 year (catalog products don't change frequently)
      _cache.set(cacheKey, products, duration: const Duration(days: 365));
      
      return products;
    } catch (e) {
      // If fetching fails, return cached data if available
      if (cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }

  /// Get all products from all distributors
  Future<List<ProductModel>> getAllDistributorProducts() async {
    const cacheKey = 'all_distributor_products';
    
    // Try to get from cache first
    final cachedData = _cache.get<List<ProductModel>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      // Fetch all distributor products
      final rows = await _supabase
          .from('distributor_products')
          .select()
          .order('added_at', ascending: false);

      if (rows.isEmpty) return [];

      // Get unique product IDs
      final productIds = rows.map((row) => row['product_id'] as String).toSet().toList();

      // Fetch product details
      final productDocs = productIds.isNotEmpty
          ? await _supabase.from('products').select().inFilter('id', productIds)
          : [];

      final productsMap = {
        for (var doc in productDocs) doc['id'].toString(): ProductModel.fromMap(doc)
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

      // Cache for 10 minutes
      _cache.set(cacheKey, products, duration: const Duration(minutes: 20));
      
      return products;
    } catch (e) {
      // If fetching fails, return cached data if available
      if (cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }

  /// إضافة منتجات متعددة لكتالوج الموزع
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

    // Schedule cache invalidation
    _scheduleCacheInvalidation();
  }

  /// إزالة منتج من كتالوج الموزع
  Future<void> removeProductFromDistributorCatalog({
    required String distributorId,
    required String productId,
    required String package,
  }) async {
    final docId = '${distributorId}_${productId}_$package';
    await _supabase.from('distributor_products').delete().eq('id', docId);

    // Schedule cache invalidation
    _scheduleCacheInvalidation();
  }

  /// إضافة منتج جديد للكتالوج الرئيسي
  Future<String?> addProductToCatalog(ProductModel product) async {
    final response =
        await _supabase.from('products').insert(product.toMap()).select();
    if (response.isNotEmpty) {
      // Schedule cache invalidation
      _scheduleCacheInvalidation();
      return response.first['id'].toString();
    }
    return null;
  }

  /// إضافة منتج واحد لكتالوج الموزع
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

    // Schedule cache invalidation
    _scheduleCacheInvalidation();
  }

  /// تحديث سعر منتج في كتالوج الموزع
  Future<void> updateProductPriceInDistributorCatalog({
    required String distributorId,
    required String productId,
    required String package,
    required double newPrice,
  }) async {
    final docId = '${distributorId}_${productId}_$package';
    await _supabase.from('distributor_products').update({
      'price': newPrice,
    }).eq('id', docId);

    // Schedule cache invalidation
    _scheduleCacheInvalidation();
  }

  /// Schedule cache invalidation with aggressive batching to prevent multiple rapid invalidations
  void _scheduleCacheInvalidation() {
    // Update the last modified timestamp immediately
    final now = DateTime.now();
    _ref.read(productDataLastModifiedProvider.notifier).state = now;

    // Cancel any existing timer
    _invalidationTimer?.cancel();

    // Schedule cache invalidation with a 100ms delay to batch multiple operations
    _invalidationTimer = Timer(const Duration(milliseconds: 100), () {
      try {
        // Invalidate all product-related caches at once
        _cache.invalidateWithPrefix('distributor_products_');
        _cache.invalidate('allDistributorProducts');
        _cache.invalidateWithPrefix('my_products_');
      } catch (e) {
        // Log error but don't fail the operation
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

/// جلب كل المنتجات
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

// --- Pagination Notifier ---
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
    // Allow first page fetch during refresh, but prevent concurrent fetches for others.
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

// --- Paginated Products Provider --- //
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
    for (var doc in productDocs) doc['id'].toString(): ProductModel.fromMap(doc)
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

/// جلب منتجات الموزع الحالي فقط
final myProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) return [];

  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  final lastModified = ref.watch(productDataLastModifiedProvider);
  final cacheKey = 'my_products_$userId';

  // Calculate cache key with last modified timestamp for proper invalidation
  final timestampedCacheKey =
      '$cacheKey-${lastModified.microsecondsSinceEpoch}-$userId';

  final cachedProducts = cache.get<List<ProductModel>>(timestampedCacheKey);
  if (cachedProducts != null) {
    return cachedProducts;
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
    for (var doc in productDocs) doc['id'].toString(): ProductModel.fromMap(doc)
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

  cache.set(timestampedCacheKey, products,
      duration: const Duration(minutes: 20));
  return products;
});
