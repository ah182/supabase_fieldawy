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
        item.product.distributorId == product.distributorId &&
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

  void removeProductsByDistributor(String distributorName) {
    state = state.where((item) => item.product.distributorId != distributorName).toList();
    _saveOrder();
  }

  void removeProductsByDistributors(Set<String> distributorNames) {
    state = state.where((item) => !distributorNames.contains(item.product.distributorId)).toList();
    _saveOrder();
  }
}

final orderProvider =
    StateNotifierProvider<OrderNotifier, List<OrderItemModel>>((ref) {
  return OrderNotifier();
});
