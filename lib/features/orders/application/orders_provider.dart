import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OrderNotifier extends StateNotifier<List<OrderItemModel>> {
  OrderNotifier() : super([]);

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
  }

  void removeProduct(OrderItemModel orderItem) {
    state = state.where((item) => item != orderItem).toList();
  }

  void incrementQuantity(OrderItemModel orderItem) {
    final updatedItem = orderItem.copyWith(quantity: orderItem.quantity + 1);
    final updatedList = state.map((item) => item.product.id == orderItem.product.id ? updatedItem : item).toList();
    state = updatedList;
  }

  void decrementQuantity(OrderItemModel orderItem) {
    if (orderItem.quantity > 1) {
      final updatedItem = orderItem.copyWith(quantity: orderItem.quantity - 1);
      final updatedList = state.map((item) => item.product.id == orderItem.product.id ? updatedItem : item).toList();
      state = updatedList;
    }
  }

  void clearOrder() {
    state = [];
  }
}

final orderProvider =
    StateNotifierProvider<OrderNotifier, List<OrderItemModel>>((ref) {
  return OrderNotifier();
});