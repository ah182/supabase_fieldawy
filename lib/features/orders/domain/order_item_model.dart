import 'package:fieldawy_store/features/products/domain/product_model.dart';

class OrderItemModel {
  final ProductModel product;
  int quantity;

  OrderItemModel({required this.product, this.quantity = 1});

  // copyWith method
  OrderItemModel copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return OrderItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
