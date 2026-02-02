import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive/hive.dart';

part 'daily_challenge_model.g.dart';

@HiveType(typeId: 20) // Ensure typeId is unique
class DailyChallengeModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final List<ProductModel> products;
  @HiveField(3)
  final String activePrinciple;
  @HiveField(4)
  final String packageType;
  @HiveField(5)
  late bool isCompleted;
  @HiveField(6)
  late bool isDismissedForNow;

  DailyChallengeModel({
    required this.id,
    required this.date,
    required this.products,
    required this.activePrinciple,
    required this.packageType,
    this.isCompleted = false,
    this.isDismissedForNow = false,
  });
}
