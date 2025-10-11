import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/application/surgical_tools_home_provider.dart';
import 'package:fieldawy_store/features/products/application/offers_home_provider.dart';
import 'package:fieldawy_store/features/products/application/expire_drugs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive/hive.dart';

// Import priceUpdatesProvider
// Already imported via product_repository.dart

// Class to store favorite product with metadata
class FavoriteProductItem {
  final ProductModel product;
  final String type; // 'home', 'price_action', 'expire_soon', 'surgical', 'offers'
  final DateTime? expirationDate; // For expire_soon
  final String? status; // For surgical (جديد/مستعمل/كسر زيرو)
  final bool showPriceChange; // For price_action
  final double? savedPrice; // Save price for price_action products
  final double? savedOldPrice; // Save oldPrice for price_action products

  FavoriteProductItem({
    required this.product,
    required this.type,
    this.expirationDate,
    this.status,
    this.showPriceChange = false,
    this.savedPrice,
    this.savedOldPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'expirationDate': expirationDate?.toIso8601String(),
      'status': status,
      'showPriceChange': showPriceChange,
      'savedPrice': savedPrice,
      'savedOldPrice': savedOldPrice,
    };
  }

  factory FavoriteProductItem.fromJson(Map<String, dynamic> json, ProductModel product) {
    // Restore oldPrice and price if saved for price_action type
    ProductModel restoredProduct = product;
    
    final savedOldPrice = json['savedOldPrice'] != null 
        ? (json['savedOldPrice'] as num).toDouble() 
        : null;
    final savedPrice = json['savedPrice'] != null 
        ? (json['savedPrice'] as num).toDouble() 
        : null;
    
    // For price_action products, use saved prices
    if (json['type'] == 'price_action' && (savedOldPrice != null || savedPrice != null)) {
      restoredProduct = product.copyWith(
        oldPrice: savedOldPrice ?? product.oldPrice,
        price: savedPrice ?? product.price,
      );
    }
    
    return FavoriteProductItem(
      product: restoredProduct,
      type: json['type'] ?? 'home',
      expirationDate: json['expirationDate'] != null 
          ? DateTime.tryParse(json['expirationDate']) 
          : null,
      status: json['status'],
      showPriceChange: json['showPriceChange'] ?? false,
      savedPrice: savedPrice,
      savedOldPrice: savedOldPrice,
    );
  }
}

class FavoritesNotifier extends StateNotifier<Map<String, Map<String, dynamic>>> {
  FavoritesNotifier() : super({}) {
    _loadFavorites();
  }

  final _box = Hive.box('favorites');

  String _getUniqueKey(ProductModel product) {
    return '${product.id}_${product.distributorId}_${product.selectedPackage}';
  }

  void _loadFavorites() {
    final Map<String, Map<String, dynamic>> loaded = {};
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        loaded[key.toString()] = Map<String, dynamic>.from(value);
      }
    }
    state = loaded;
  }

  Future<void> _updateHiveBox() async {
    await _box.clear();
    for (var entry in state.entries) {
      await _box.put(entry.key, entry.value);
    }
  }

  void addToFavorites(ProductModel product, {
    String type = 'home',
    DateTime? expirationDate,
    String? status,
    bool showPriceChange = false,
  }) {
    final key = _getUniqueKey(product);
    if (!state.containsKey(key)) {
      state = {
        ...state,
        key: {
          'type': type,
          'expirationDate': expirationDate?.toIso8601String(),
          'status': status,
          'showPriceChange': showPriceChange,
          'savedPrice': product.price,
          'savedOldPrice': product.oldPrice,
        }
      };
      _updateHiveBox();
    }
  }

  void removeFromFavorites(ProductModel product) {
    final key = _getUniqueKey(product);
    if (state.containsKey(key)) {
      state = Map.from(state)..remove(key);
      _updateHiveBox();
    }
  }

  bool isFavorite(ProductModel product) {
    final key = _getUniqueKey(product);
    return state.containsKey(key);
  }

  void toggleFavorite(ProductModel product, {
    String type = 'home',
    DateTime? expirationDate,
    String? status,
    bool showPriceChange = false,
  }) {
    if (isFavorite(product)) {
      removeFromFavorites(product);
    } else {
      addToFavorites(
        product,
        type: type,
        expirationDate: expirationDate,
        status: status,
        showPriceChange: showPriceChange,
      );
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Map<String, Map<String, dynamic>>>((ref) {
  return FavoritesNotifier();
});

final favoriteProductsProvider = FutureProvider<List<FavoriteProductItem>>((ref) async {
  final favoritesMap = ref.watch(favoritesProvider);
  
  if (favoritesMap.isEmpty) {
    return [];
  }

  // Collect all products from different sources
  final Map<String, ProductModel> allProductsMap = {};

  // 1. Get products from distributor_products and distributor_ocr_products
  try {
    final distributorProducts = await ref.watch(allDistributorProductsProvider.future);
    for (final product in distributorProducts) {
      final key = '${product.id}_${product.distributorId}_${product.selectedPackage}';
      allProductsMap[key] = product;
    }
  } catch (e) {
    print('Error loading distributor products for favorites: $e');
  }

  // 2. Get products from surgical tools
  try {
    final surgicalTools = await ref.watch(surgicalToolsHomeProvider.future);
    for (final product in surgicalTools) {
      final key = '${product.id}_${product.distributorId}_${product.selectedPackage}';
      allProductsMap[key] = product;
    }
  } catch (e) {
    print('Error loading surgical tools for favorites: $e');
  }

  // 3. Get products from offers
  try {
    final offers = await ref.watch(offersHomeProvider.future);
    for (final item in offers) {
      final key = '${item.product.id}_${item.product.distributorId}_${item.product.selectedPackage}';
      allProductsMap[key] = item.product;
    }
  } catch (e) {
    print('Error loading offers for favorites: $e');
  }

  // 4. Get products from expire soon items
  try {
    final expireItems = await ref.watch(expireDrugsProvider.future);
    for (final item in expireItems) {
      final key = '${item.product.id}_${item.product.distributorId}_${item.product.selectedPackage}';
      allProductsMap[key] = item.product;
    }
  } catch (e) {
    print('Error loading expire drugs for favorites: $e');
  }

  // 5. Get products from price updates (with oldPrice and price)
  try {
    final priceUpdates = await ref.watch(priceUpdatesProvider.future);
    for (final product in priceUpdates) {
      final key = '${product.id}_${product.distributorId}_${product.selectedPackage}';
      // Override with price update data to ensure oldPrice is present
      allProductsMap[key] = product;
    }
  } catch (e) {
    print('Error loading price updates for favorites: $e');
  }

  // Build FavoriteProductItem list from favoritesMap
  final List<FavoriteProductItem> favoriteItems = [];
  for (final entry in favoritesMap.entries) {
    final key = entry.key;
    final metadata = entry.value;
    var product = allProductsMap[key];
    
    if (product != null) {
      // For price_action products, restore saved prices BEFORE creating FavoriteProductItem
      if (metadata['type'] == 'price_action') {
        final savedOldPrice = metadata['savedOldPrice'] != null 
            ? (metadata['savedOldPrice'] as num).toDouble() 
            : null;
        final savedPrice = metadata['savedPrice'] != null 
            ? (metadata['savedPrice'] as num).toDouble() 
            : null;
        
        if (savedOldPrice != null || savedPrice != null) {
          product = product.copyWith(
            oldPrice: savedOldPrice ?? product.oldPrice,
            price: savedPrice ?? product.price,
          );
        }
      }
      
      favoriteItems.add(FavoriteProductItem.fromJson(metadata, product));
    }
  }

  return favoriteItems;
});