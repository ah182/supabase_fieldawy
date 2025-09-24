import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive/hive.dart';

part 'order_item_model.g.dart';

@HiveType(typeId: 1)
class OrderItemModel {
  @HiveField(0)
  final ProductModel product;

  @HiveField(1)
  int quantity;

  OrderItemModel({required this.product, this.quantity = 1});

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