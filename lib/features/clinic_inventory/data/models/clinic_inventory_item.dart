import 'package:equatable/equatable.dart';

/// حالة المخزون
enum StockStatus {
  adequate, // كافي
  low, // منخفض
  critical, // حرج
  outOfStock // نفذ
}

/// حالة الصلاحية
enum ExpiryStatus {
  ok, // صالح
  warning, // قارب الانتهاء (90 يوم)
  critical, // قريب جداً (30 يوم)
  expired, // منتهي
  unknown // غير محدد
}

/// نوع العملية
enum TransactionType {
  add, // إضافة
  sell, // بيع
  adjust, // تعديل
  expired, // انتهاء صلاحية
  returnItem // مرتجع
}

/// نموذج عنصر الجرد
class ClinicInventoryItem extends Equatable {
  final String id;
  final String userId;
  final String sourceType; // 'catalog', 'ocr', 'manual'
  final String? sourceProductId;
  final String? sourceOcrProductId;

  final String productName;
  final String? productNameEn;
  final String package;
  final String? company;
  final String? imageUrl;
  final String packageType; // 'box', 'bottle', 'vial', 'ampoule', etc.

  // الكميات
  final int quantity; // عدد العلب الكاملة
  final double partialQuantity; // الكمية الجزئية المتبقية
  final String unitType; // 'box', 'ml', 'gram', 'piece'
  final double unitSize; // حجم الوحدة
  final int minStock; // الحد الأدنى

  // السعر
  final double purchasePrice;

  // التفاصيل
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClinicInventoryItem({
    required this.id,
    required this.userId,
    required this.sourceType,
    this.sourceProductId,
    this.sourceOcrProductId,
    required this.productName,
    this.productNameEn,
    required this.package,
    this.company,
    this.imageUrl,
    this.packageType = 'box',
    required this.quantity,
    this.partialQuantity = 0,
    this.unitType = 'box',
    this.unitSize = 1,
    this.minStock = 3,
    required this.purchasePrice,
    this.expiryDate,
    this.batchNumber,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// إجمالي الكمية بالوحدة الأساسية
  double get totalQuantityInUnits {
    return (quantity * unitSize) + partialQuantity;
  }

  /// حساب سعر الوحدة الواحدة
  double get pricePerUnit {
    if (unitSize <= 0) return purchasePrice;
    return purchasePrice / unitSize;
  }

  /// حالة المخزون
  StockStatus get stockStatus {
    if (quantity <= 0 && partialQuantity <= 0) {
      return StockStatus.outOfStock;
    }
    if (quantity < (minStock / 2)) {
      return StockStatus.critical;
    }
    if (quantity < minStock) {
      return StockStatus.low;
    }
    return StockStatus.adequate;
  }

  /// حالة الصلاحية
  ExpiryStatus get expiryStatus {
    if (expiryDate == null) return ExpiryStatus.unknown;

    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;

    if (daysLeft < 0) return ExpiryStatus.expired;
    if (daysLeft < 30) return ExpiryStatus.critical;
    if (daysLeft < 90) return ExpiryStatus.warning;
    return ExpiryStatus.ok;
  }

  /// الأيام المتبقية للصلاحية
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// من JSON
  factory ClinicInventoryItem.fromJson(Map<String, dynamic> json) {
    // Logic to handle potential data overlap if existing data used unit_type for ml/gm
    final dbUnitType = json['unit_type'] as String? ?? 'box';
    String finalPackageType = 'box';
    String finalUnitType = 'piece';

    // Heuristic: If DB unit_type matches known package types, use it for packageType
    if ([
      'box',
      'bottle',
      'vial',
      'ampoule',
      'tube',
      'sachet',
      'strip',
      'can',
      'jar',
      'bag'
    ].contains(dbUnitType)) {
      finalPackageType = dbUnitType;
    } else {
      // Otherwise, assume it was legacy unit type (ml/gram)
      finalPackageType = 'box'; // Default
      finalUnitType = dbUnitType;
    }

    return ClinicInventoryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sourceType: json['source_type'] as String? ?? 'manual',
      sourceProductId: json['source_product_id'] as String?,
      sourceOcrProductId: json['source_ocr_product_id'] as String?,
      productName: json['product_name'] as String,
      productNameEn: json['product_name_en'] as String?,
      package: json['package'] as String,
      company: json['company'] as String?,
      imageUrl: json['image_url'] as String?,
      packageType: finalPackageType, // Mapped from unit_type
      quantity: json['quantity'] as int? ?? 0,
      partialQuantity: (json['partial_quantity'] as num?)?.toDouble() ?? 0,
      unitType: finalUnitType, // Derived or default
      unitSize: (json['unit_size'] as num?)?.toDouble() ?? 1,
      minStock: json['min_stock'] as int? ?? 3,
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      batchNumber: json['batch_number'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'source_type': sourceType,
      'source_product_id': sourceProductId,
      'source_ocr_product_id': sourceOcrProductId,
      'product_name': productName,
      'product_name_en': productNameEn,
      'package': package,
      'company': company,
      'image_url': imageUrl,
      // 'package_type': packageType, // Column removed
      'quantity': quantity,
      'partial_quantity': partialQuantity,
      'unit_type':
          packageType, // Store packageType (Bottle/Box) in unit_type column
      'unit_size': unitSize,
      'min_stock': minStock,
      'purchase_price': purchasePrice,
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'batch_number': batchNumber,
      'notes': notes,
      'is_active': isActive,
    };
  }

  /// للإدراج (بدون id و timestamps)
  Map<String, dynamic> toInsertJson() {
    final json = toJson();
    json.remove('id');
    json.remove('created_at');
    json.remove('updated_at');
    return json;
  }

  /// نسخة معدلة
  ClinicInventoryItem copyWith({
    String? id,
    String? userId,
    String? sourceType,
    String? sourceProductId,
    String? sourceOcrProductId,
    String? productName,
    String? productNameEn,
    String? package,
    String? company,
    String? imageUrl,
    String? packageType,
    int? quantity,
    double? partialQuantity,
    String? unitType,
    double? unitSize,
    int? minStock,
    double? purchasePrice,
    DateTime? expiryDate,
    String? batchNumber,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClinicInventoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourceType: sourceType ?? this.sourceType,
      sourceProductId: sourceProductId ?? this.sourceProductId,
      sourceOcrProductId: sourceOcrProductId ?? this.sourceOcrProductId,
      productName: productName ?? this.productName,
      productNameEn: productNameEn ?? this.productNameEn,
      package: package ?? this.package,
      company: company ?? this.company,
      imageUrl: imageUrl ?? this.imageUrl,
      packageType: packageType ?? this.packageType,
      quantity: quantity ?? this.quantity,
      partialQuantity: partialQuantity ?? this.partialQuantity,
      unitType: unitType ?? this.unitType,
      unitSize: unitSize ?? this.unitSize,
      minStock: minStock ?? this.minStock,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, quantity, partialQuantity, updatedAt];
}

extension ClinicInventoryItemX on ClinicInventoryItem {
  String get translatedPackageType {
    switch (packageType) {
      case 'box':
        return 'علبة';
      case 'bottle':
        return 'زجاجة';
      case 'vial':
        return 'فيال';
      case 'ampoule':
        return 'أمبول';
      case 'tube':
        return 'أنبوب';
      case 'strip':
        return 'شريط';
      case 'sachet':
        return 'كيس';
      case 'can':
        return 'علبة معدنية';
      case 'jar':
        return 'برطمان';
      case 'bag':
        return 'كيس محلول';
      default:
        return packageType;
    }
  }

  String get translatedUnitType {
    // محاولة استخراج الوحدة من اسم العبوة إذا كانت الوحدة المسجلة عامة
    if (unitType == 'piece' || unitType == 'box') {
      final lowerPkg = package.toLowerCase();
      if (lowerPkg.contains('ml')) return 'مل';
      if (lowerPkg.contains('gm') ||
          lowerPkg.contains(' g ') ||
          lowerPkg.endsWith(' g')) return 'جرام';
      if (lowerPkg.contains('mg')) return 'مجم';
      if (lowerPkg.contains('kg')) return 'كجم';
      if (lowerPkg.contains('cm')) return 'سم';
      if (lowerPkg.contains('liter') ||
          (lowerPkg.contains(' l ') && !lowerPkg.contains('oil'))) return 'لتر';
    }

    switch (unitType) {
      case 'ml':
        return 'مل';
      case 'gram':
      case 'g':
        return 'جرام';
      case 'tablet':
      case 'tab':
        return 'قرص';
      case 'capsule':
      case 'cap':
        return 'كبسولة';
      case 'ampoule':
      case 'amp':
        return 'أمبول';
      case 'vial':
        return 'فيال';
      case 'piece':
        return 'وحدة';
      default:
        return unitType;
    }
  }
}
