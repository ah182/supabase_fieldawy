import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';

// كلاس لحفظ حالة الاختيارات
class CatalogSelection {
  final Map<String, double> prices; // key: 'productId_package', value: price
  CatalogSelection({this.prices = const {}});

  CatalogSelection copyWith({Map<String, double>? prices}) {
    return CatalogSelection(prices: prices ?? this.prices);
  }
}

class CatalogSelectionController extends StateNotifier<CatalogSelection> {
  final Ref _ref;
  CatalogSelectionController(this._ref) : super(CatalogSelection());

  // دالة لتحديث سعر منتج مختار
  void setPrice(String productId, String package, String priceText) {
    final price = double.tryParse(priceText);
    if (price == null) return;

    final key = '${productId}_$package';
    final newPrices = Map<String, double>.from(state.prices);
    if (newPrices.containsKey(key)) {
      newPrices[key] = price;
      state = state.copyWith(prices: newPrices);
    }
  }

  // ✅ دالة لإزالة سعر منتج (تُستخدم لما الحقل يبقى فاضي)
  void removePrice(String productId, String package) {
    final key = '${productId}_$package';
    final newPrices = Map<String, double>.from(state.prices);
    if (newPrices.containsKey(key)) {
      newPrices.remove(key);
      state = state.copyWith(prices: newPrices);
    }
  }

  // دالة لإضافة أو إزالة منتج من قائمة الاختيار
  void toggleProduct(
      String productId, String package, String currentPriceText) {
    final key = '${productId}_$package';
    final newPrices = Map<String, double>.from(state.prices);

    if (newPrices.containsKey(key)) {
      newPrices.remove(key);
    } else {
      final price = double.tryParse(currentPriceText);
      // أضف المنتج إلى القائمة بسعره الحالي (حتى لو كان صفرًا)، التحقق يتم عند الحفظ
      newPrices[key] = price ?? 0.0;
    }
    state = state.copyWith(prices: newPrices);
  }

  // دالة لحفظ كل المنتجات المختارة في Supabase
  Future<bool> saveSelections() async {
    final distributor = _ref.read(userDataProvider).asData?.value;
    if (distributor == null || state.prices.isEmpty) {
      return false;
    }

    // فلترة المنتجات التي لم يتم تسعيرها (سعرها صفر أو أقل)
    final validSelections = Map<String, double>.from(state.prices)
      ..removeWhere((key, price) => price <= 0);

    if (validSelections.isEmpty) {
      print('No valid selections to save.');
      return false;
    }

    try {
      await _ref
          .read(productRepositoryProvider)
          .addMultipleProductsToDistributorCatalog(
            distributorId: distributor.id,
            distributorName: distributor.displayName ?? 'اسم غير معروف',
            productsToAdd: validSelections,
          );
      
      // Invalidate cache for my products
      _ref.read(cachingServiceProvider).invalidateWithPrefix('my_products_');
      _ref.invalidate(myProductsProvider);

      state = CatalogSelection(); // إفراغ القائمة بعد الحفظ
      return true;
    } catch (e) {
      print('Failed to save selections: $e');
      return false;
    }
  }
}

// Provider للوصول إلى المتحكم
final catalogSelectionControllerProvider =
    StateNotifierProvider<CatalogSelectionController, CatalogSelection>((ref) {
  return CatalogSelectionController(ref);
});
