import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';

// كلاس لحفظ حالة الاختيارات
class CatalogSelection {
  final Map<String, double> prices; // key: 'productId_package', value: price (سواء محدد أو لا)
  final Set<String> selectedKeys; // المنتجات المحددة (التوجل مفعل)
  final Map<String, DateTime> expirationDates; // key: 'productId_package', value: expiration date
  
  CatalogSelection({
    this.prices = const {}, 
    this.selectedKeys = const {},
    this.expirationDates = const {},
  });

  CatalogSelection copyWith({
    Map<String, double>? prices, 
    Object? selectedKeys = const _Placeholder(),
    Map<String, DateTime>? expirationDates,
  }) {
    return CatalogSelection(
      prices: prices ?? this.prices,
      selectedKeys: selectedKeys is _Placeholder 
          ? this.selectedKeys 
          : (selectedKeys as Set<String>? ?? const {}),
      expirationDates: expirationDates ?? this.expirationDates,
    );
  }
}

class _Placeholder {
  const _Placeholder();
}

class CatalogSelectionController extends StateNotifier<CatalogSelection> {
  final Ref _ref;
  CatalogSelectionController(this._ref) : super(CatalogSelection());

  // دالة لتحديث سعر منتج (سواء محدد أو لا)
  void setPrice(String productId, String package, String priceText) {
    final price = double.tryParse(priceText);
    if (price == null) return;

    final key = '${productId}_$package';
    final newPrices = Map<String, double>.from(state.prices);
    newPrices[key] = price; // نحفظ السعر حتى لو المنتج مش محدد
    state = state.copyWith(prices: newPrices);
  }

  void setExpirationDate(String productId, String package, DateTime date) {
    final key = '${productId}_$package';
    final newExpirationDates = Map<String, DateTime>.from(state.expirationDates);
    newExpirationDates[key] = date;
    state = state.copyWith(expirationDates: newExpirationDates);
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
    final newSelectedKeys = Set<String>.from(state.selectedKeys);
    final newExpirationDates = Map<String, DateTime>.from(state.expirationDates);

    if (newSelectedKeys.contains(key)) {
      // إلغاء التحديد - نزيل من selectedKeys لكن نحتفظ بالسعر
      newSelectedKeys.remove(key);
      newExpirationDates.remove(key);
    } else {
      // تحديد - نضيف للـ selectedKeys ونحفظ السعر
      final price = double.tryParse(currentPriceText);
      newPrices[key] = price ?? 0.0;
      newSelectedKeys.add(key);
    }
    state = state.copyWith(
      prices: newPrices, 
      selectedKeys: newSelectedKeys,
      expirationDates: newExpirationDates,
    );
  }

  // دالة لحفظ كل المنتجات المختارة في Supabase
  Future<bool> saveSelections({Set<String>? keysToSave, bool withExpiration = false}) async {
    final distributor = _ref.read(userDataProvider).asData?.value;
    if (distributor == null || state.selectedKeys.isEmpty) {
      return false;
    }

    // Start with selected items only
    var selectionsToSave = Map<String, double>.from(state.prices)
      ..removeWhere((key, value) => !state.selectedKeys.contains(key));

    // If specific keys are provided, filter for them
    if (keysToSave != null) {
      selectionsToSave.removeWhere((key, value) => !keysToSave.contains(key));
    }

    // Filter for products that have a valid price
    final validSelections = Map<String, double>.from(selectionsToSave)
      ..removeWhere((key, price) => price <= 0);

    if (validSelections.isEmpty) {
      print('No valid selections to save.');
      return false;
    }

    final productsToAdd = validSelections.map((key, value) {
      final expirationDate = state.expirationDates[key];
      return MapEntry(key, {
        'price': value,
        'expiration_date': withExpiration && expirationDate != null ? expirationDate.toIso8601String() : null,
      });
    });

    try {
      await _ref
          .read(productRepositoryProvider)
          .addMultipleProductsToDistributorCatalog(
            distributorId: distributor.id,
            distributorName: distributor.displayName ?? 'اسم غير معروف',
            productsToAdd: productsToAdd,
          );
      
      // Invalidate cache for my products
      _ref.read(cachingServiceProvider).invalidateWithPrefix('my_products_');
      _ref.invalidate(myProductsProvider);

      // Remove only the saved selections from the state
      final newPrices = Map<String, double>.from(state.prices)
        ..removeWhere((key, value) => validSelections.containsKey(key));
      final newSelectedKeys = Set<String>.from(state.selectedKeys)
        ..removeWhere((key) => validSelections.containsKey(key));
      final newExpirationDates = Map<String, DateTime>.from(state.expirationDates)
        ..removeWhere((key, value) => validSelections.containsKey(key));
      state = state.copyWith(
        prices: newPrices, 
        selectedKeys: newSelectedKeys,
        expirationDates: newExpirationDates,
      );
      
      return true;
    } catch (e) {
      print('Failed to save selections: $e');
      return false;
    }
  }

  void clearSelections(Set<String> keysToClear) {
    final newPrices = Map<String, double>.from(state.prices)
      ..removeWhere((key, value) => keysToClear.contains(key));
    final newSelectedKeys = Set<String>.from(state.selectedKeys)
      ..removeWhere((key) => keysToClear.contains(key));
    final newExpirationDates = Map<String, DateTime>.from(state.expirationDates)
      ..removeWhere((key, value) => keysToClear.contains(key));
    state = state.copyWith(
      prices: newPrices, 
      selectedKeys: newSelectedKeys,
      expirationDates: newExpirationDates,
    );
  }

  // مسح كل الاختيارات
  void clearAll() {
    state = CatalogSelection(
      prices: {},
      selectedKeys: {},
      expirationDates: {},
    );
  }
}

// Provider للوصول إلى المتحكم

enum CatalogContext {
  myProducts,
  offers,
  reviews,
}

final catalogSelectionControllerProvider = StateNotifierProvider.family<
    CatalogSelectionController, CatalogSelection, CatalogContext>((ref, context) {
  return CatalogSelectionController(ref);
});
