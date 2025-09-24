import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive/hive.dart';

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  final _box = Hive.box<String>('favorites');

  String _getUniqueKey(ProductModel product) {
    return '${product.id}_${product.distributorId}_${product.selectedPackage}';
  }

  void _loadFavorites() {
    state = _box.values.toList();
  }

  Future<void> _updateHiveBox() async {
    await _box.clear();
    await _box.addAll(state);
  }

  void addToFavorites(ProductModel product) {
    final key = _getUniqueKey(product);
    if (!state.contains(key)) {
      state = [...state, key];
      _updateHiveBox();
    }
  }

  void removeFromFavorites(ProductModel product) {
    final key = _getUniqueKey(product);
    final originalLength = state.length;
    state = state.where((k) => k != key).toList();
    if (state.length < originalLength) {
      _updateHiveBox();
    }
  }

  bool isFavorite(ProductModel product) {
    final key = _getUniqueKey(product);
    return state.contains(key);
  }

  void toggleFavorite(ProductModel product) {
    if (isFavorite(product)) {
      removeFromFavorites(product);
    } else {
      addToFavorites(product);
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

final favoriteProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider);
  final allProductsAsync = ref.watch(internalAllProductsProvider);

  return allProductsAsync.when(
    data: (products) {
      return products.where((product) {
        final key = '${product.id}_${product.distributorId}_${product.selectedPackage}';
        return favoriteIds.contains(key);
      }).toList();
    },
    loading: () => [],
    error: (err, stack) => throw err,
  );
});