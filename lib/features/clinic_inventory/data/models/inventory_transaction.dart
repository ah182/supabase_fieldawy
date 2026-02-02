import 'package:equatable/equatable.dart';
import 'clinic_inventory_item.dart';

/// نموذج عملية الجرد
class InventoryTransaction extends Equatable {
  final String id;
  final String inventoryId;
  final String userId;
  final TransactionType transactionType;
  final DateTime transactionDate;

  // بيانات المنتج
  final String? productName;
  final String? package;

  // للإضافة
  final int boxesAdded;
  final double? purchasePricePerBox;
  final double? totalPurchaseCost;

  // للبيع
  final double quantitySold;
  final String? unitSold;
  final double? sellingPrice;

  // حسابات المكسب
  final double? costOfSold;
  final double? profit;

  final String? notes;
  final DateTime createdAt;

  const InventoryTransaction({
    required this.id,
    required this.inventoryId,
    required this.userId,
    required this.transactionType,
    required this.transactionDate,
    this.productName,
    this.package,
    this.boxesAdded = 0,
    this.purchasePricePerBox,
    this.totalPurchaseCost,
    this.quantitySold = 0,
    this.unitSold,
    this.sellingPrice,
    this.costOfSold,
    this.profit,
    this.notes,
    required this.createdAt,
  });

  /// من JSON
  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: json['id'] as String,
      inventoryId: json['inventory_id'] as String,
      userId: json['user_id'] as String,
      transactionType:
          _parseTransactionType(json['transaction_type'] as String),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      productName: json['product_name'] as String?,
      package: json['package'] as String?,
      boxesAdded: json['boxes_added'] as int? ?? 0,
      purchasePricePerBox: (json['purchase_price_per_box'] as num?)?.toDouble(),
      totalPurchaseCost: (json['total_purchase_cost'] as num?)?.toDouble(),
      quantitySold: (json['quantity_sold'] as num?)?.toDouble() ?? 0,
      unitSold: json['unit_sold'] as String?,
      sellingPrice: (json['selling_price'] as num?)?.toDouble(),
      costOfSold: (json['cost_of_sold'] as num?)?.toDouble(),
      profit: (json['profit'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'inventory_id': inventoryId,
      'user_id': userId,
      'transaction_type': transactionType.name,
      'transaction_date': transactionDate.toIso8601String().split('T')[0],
      'product_name': productName,
      'package': package,
      'boxes_added': boxesAdded,
      'purchase_price_per_box': purchasePricePerBox,
      'total_purchase_cost': totalPurchaseCost,
      'quantity_sold': quantitySold,
      'unit_sold': unitSold,
      'selling_price': sellingPrice,
      'cost_of_sold': costOfSold,
      'profit': profit,
      'notes': notes,
    };
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'add':
        return TransactionType.add;
      case 'sell':
        return TransactionType.sell;
      case 'adjust':
        return TransactionType.adjust;
      case 'expired':
        return TransactionType.expired;
      case 'return':
      case 'returnItem':
        return TransactionType.returnItem;
      default:
        return TransactionType.adjust;
    }
  }

  @override
  List<Object?> get props => [id, inventoryId, transactionType, createdAt];
}

/// ملخص التقرير اليومي
class DailySummary extends Equatable {
  final DateTime date;
  final int addCount;
  final double totalPurchase;
  final int totalBoxesAdded;
  final int sellCount;
  final double totalSales;
  final double totalCost;
  final double totalProfit;

  const DailySummary({
    required this.date,
    this.addCount = 0,
    this.totalPurchase = 0,
    this.totalBoxesAdded = 0,
    this.sellCount = 0,
    this.totalSales = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
  });

  /// نسبة الربح
  double get profitMargin {
    if (totalSales <= 0) return 0;
    return (totalProfit / totalSales) * 100;
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['transaction_date'] as String),
      addCount: json['add_count'] as int? ?? 0,
      totalPurchase: (json['total_purchase'] as num?)?.toDouble() ?? 0,
      totalBoxesAdded: json['total_boxes_added'] as int? ?? 0,
      sellCount: json['sell_count'] as int? ?? 0,
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [date, totalSales, totalProfit];
}

/// ملخص التقارير
class InventoryReportSummary extends Equatable {
  final String periodType; // 'daily', 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final List<DailySummary> dailySummaries;

  const InventoryReportSummary({
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.dailySummaries,
  });

  /// إجمالي المشتريات
  double get totalPurchases =>
      dailySummaries.fold(0, (sum, d) => sum + d.totalPurchase);

  /// إجمالي المبيعات
  double get totalSales =>
      dailySummaries.fold(0, (sum, d) => sum + d.totalSales);

  /// إجمالي المكسب
  double get totalProfit =>
      dailySummaries.fold(0, (sum, d) => sum + d.totalProfit);

  /// عدد الإضافات
  int get totalAddCount => dailySummaries.fold(0, (sum, d) => sum + d.addCount);

  /// عدد المبيعات
  int get totalSellCount =>
      dailySummaries.fold(0, (sum, d) => sum + d.sellCount);

  /// نسبة الربح
  double get profitMargin {
    if (totalSales <= 0) return 0;
    return (totalProfit / totalSales) * 100;
  }

  @override
  List<Object?> get props => [periodType, startDate, endDate];
}
