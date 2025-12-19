import 'package:collection/collection.dart';
import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OrderNotifier extends StateNotifier<List<OrderItemModel>> {
  OrderNotifier() : super([]) {
    _loadOrder();
  }

  final _box = Hive.box<OrderItemModel>('orders');

  void _loadOrder() {
    state = _box.values.toList();
  }

  Future<void> _saveOrder() async {
    await _box.clear();
    for (int i = 0; i < state.length; i++) {
      await _box.put(i, state[i]);
    }
  }

  void addProduct(ProductModel product) {
    final existingIndex = state.indexWhere((item) =>
        item.product.id == product.id &&
        item.product.distributorUuid == product.distributorUuid &&
        item.product.selectedPackage == product.selectedPackage);

    if (existingIndex != -1) {
      final updatedItem = state[existingIndex].copyWith(quantity: state[existingIndex].quantity + 1);
      final updatedList = List<OrderItemModel>.from(state);
      updatedList[existingIndex] = updatedItem;
      state = updatedList;
    } else {
      state = [...state, OrderItemModel(product: product)];
    }
    _saveOrder();
  }

  void removeProduct(OrderItemModel orderItem) {
    state = state.where((item) => item != orderItem).toList();
    _saveOrder();
  }

  void incrementQuantity(OrderItemModel orderItem) {
    final updatedItem = orderItem.copyWith(quantity: orderItem.quantity + 1);
    final updatedList = state.map((item) => item.product.id == orderItem.product.id ? updatedItem : item).toList();
    state = updatedList;
    _saveOrder();
  }

  void decrementQuantity(OrderItemModel orderItem) {
    if (orderItem.quantity > 1) {
      final updatedItem = orderItem.copyWith(quantity: orderItem.quantity - 1);
      final updatedList = state.map((item) => item.product.id == orderItem.product.id ? updatedItem : item).toList();
      state = updatedList;
      _saveOrder();
    }
  }

  void clearOrder() {
    state = [];
    _box.clear();
  }

  /// يقوم بتحديث السلة لتعويض الـ UUIDs الناقصة أو المغلوطة بناءً على قائمة الموزعين المتوفرة
  void migrateOrders(List<dynamic> distributorsData) {
    bool changed = false;
    final updatedList = state.map((item) {
      final p = item.product;
      
      // التحقق مما إذا كان الـ UUID الحالي مغلوطاً (يحتوي على اسم بدلاً من ID)
      // المعرف الحقيقي عادة ما يكون طويل ويحتوي على شُرط (Hyphens)
      bool isInvalidUuid = p.distributorUuid == null || 
                          p.distributorUuid!.isEmpty || 
                          !p.distributorUuid!.contains('-'); // المعرفات الحقيقية UUID تحتوي على '-'

      if (!isInvalidUuid) {
        return item;
      }

      // البحث عن الموزع بمطابقة الاسم القديم المخزن في السلة
      final distributor = distributorsData.firstWhereOrNull((d) {
        final name = d is Map ? d['display_name'] : d.displayName;
        // مطابقة الاسم المخزن في distributorId أو حتى الاسم المغلوط في distributorUuid
        return name == p.distributorId || name == p.distributorUuid;
      });

      if (distributor != null) {
        final uuid = distributor is Map ? distributor['id'] : distributor.id;
        final actualName = distributor is Map ? distributor['display_name'] : distributor.displayName;
        
        changed = true;
        print('♻️ Migrating product ${p.name}: Old Name/ID "${p.distributorUuid}" -> New UUID "$uuid"');
        
        return item.copyWith(
          product: p.copyWith(
            distributorUuid: uuid,
            distributorId: actualName, // تحديث الاسم أيضاً ليكون متوافقاً
          ),
        );
      }
      return item;
    }).toList();

    if (changed) {
      state = updatedList;
      _saveOrder();
    }
  }

  void removeProductsByDistributor(String distributorName) {
    state = state.where((item) => item.product.distributorId != distributorName).toList();
    _saveOrder();
  }

  void removeProductsByDistributorUuid(String distributorUuid, [List<String>? alternativeNames]) {
    state = state.where((item) {
      final p = item.product;
      // 1. مسح إذا طابق الـ UUID
      if (p.distributorUuid != null && p.distributorUuid == distributorUuid) return false;
      
      // 2. مسح إذا طابق أي من الأسماء البديلة (القديمة أو الجديدة)
      if (alternativeNames != null) {
        for (final name in alternativeNames) {
          if (p.distributorId == name || p.distributorUuid == name) return false;
        }
      }
      return true;
    }).toList();
    _saveOrder();
  }

  void removeProductsByDistributors(Set<String> distributorUuuids) {
    state = state.where((item) => !distributorUuuids.contains(item.product.distributorUuid)).toList();
    _saveOrder();
  }
}

final orderProvider =
    StateNotifierProvider<OrderNotifier, List<OrderItemModel>>((ref) {
  return OrderNotifier();
});
