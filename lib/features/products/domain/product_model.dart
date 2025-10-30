import 'package:hive/hive.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String? description;
  @HiveField(3)
  final String? activePrinciple;
  @HiveField(4)
  final String? company;
  @HiveField(5)
  final String? action;
  @HiveField(6)
  final String? package;
  @HiveField(7)
  final List<String> availablePackages;
  @HiveField(8)
  final String imageUrl;
  @HiveField(9)
  final double? price;
  @HiveField(10)
  final String? distributorId;
  @HiveField(11)
  final DateTime? createdAt;
  @HiveField(12)
  final String? selectedPackage;
  @HiveField(13)
  late bool isFavorite;
  final double? oldPrice;
  final DateTime? priceUpdatedAt;
  @HiveField(14)
  final int views;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.activePrinciple,
    this.company,
    this.action,
    this.package,
    required this.availablePackages,
    required this.imageUrl,
    this.price,
    this.distributorId,
    this.createdAt,
    this.selectedPackage,
    this.isFavorite = false,
    this.oldPrice,
    this.priceUpdatedAt,
    this.views = 0,
  });

  // --- من Supabase (row) ---
  factory ProductModel.fromMap(Map<String, dynamic> data) {
    final String packageString = data['package'] ?? '';

    final packages = packageString
        .split('-')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();

    return ProductModel(
      id: data['id'].toString(),
      name: data['name'] ?? 'Unnamed Product',
      description: data['description'] as String?,
      activePrinciple: data['active_principle'] as String?,
      company: data['company'] as String?,
      action: data['action'] as String?,
      package: packageString,
      availablePackages: packages.isNotEmpty ? packages : [packageString],
      imageUrl: data['image_url'] ?? '',
      price: (data['price'] as num?)?.toDouble(),
      oldPrice: (data['old_price'] as num?)?.toDouble(),
      distributorId: data['distributor_id'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      priceUpdatedAt: data['price_updated_at'] != null
          ? DateTime.tryParse(data['price_updated_at'].toString())
          : null,
      selectedPackage: data['selected_package'] as String?,
      views: (data['views'] as int?) ?? 0,
    );
  }

  // --- للـ insert/update في Supabase ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'active_principle': activePrinciple,
      'company': company,
      'action': action,
      'package': package,
      'available_packages': availablePackages,
      'image_url': imageUrl,
      'price': price,
      'old_price': oldPrice,
      'distributor_id': distributorId,
      'created_at': createdAt?.toIso8601String(),
      'price_updated_at': priceUpdatedAt?.toIso8601String(),
      'selected_package': selectedPackage,
      'is_favorite': isFavorite,
      'views': views,
    };
  }

  // --- نسخة JSON (لو عايزها) ---
  Map<String, dynamic> toJson() => toMap();

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel.fromMap(json);
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? activePrinciple,
    String? company,
    String? action,
    String? package,
    List<String>? availablePackages,
    String? imageUrl,
    double? price,
    double? oldPrice,
    String? distributorId,
    DateTime? createdAt,
    DateTime? priceUpdatedAt,
    String? selectedPackage,
    bool? isFavorite,
    int? views,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      activePrinciple: activePrinciple ?? this.activePrinciple,
      company: company ?? this.company,
      action: action ?? this.action,
      package: package ?? this.package,
      availablePackages: availablePackages ?? this.availablePackages,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      distributorId: distributorId ?? this.distributorId,
      createdAt: createdAt ?? this.createdAt,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      selectedPackage: selectedPackage ?? this.selectedPackage,
      isFavorite: isFavorite ?? this.isFavorite,
      views: views ?? this.views,
    );
  }
}

// OCR Product Model - matches the ocr_products table structure
@HiveType(typeId: 1)
class OCRProductModel {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String distributorId;
  
  @HiveField(2)
  final String distributorName;
  
  @HiveField(3)
  final String productName;
  
  @HiveField(4)
  final String productCompany;
  
  @HiveField(5)
  final String activePrinciple;
  
  @HiveField(6)
  final String package;
  
  @HiveField(7)
  final String imageUrl;
  
  @HiveField(8)
  final DateTime? createdAt;

  OCRProductModel({
    required this.id,
    required this.distributorId,
    required this.distributorName,
    required this.productName,
    required this.productCompany,
    required this.activePrinciple,
    required this.package,
    required this.imageUrl,
    this.createdAt,
  });

  factory OCRProductModel.fromMap(Map<String, dynamic> map) {
    return OCRProductModel(
      id: map['id']?.toString() ?? '',
      distributorId: map['distributor_id']?.toString() ?? '',
      distributorName: map['distributor_name']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      productCompany: map['product_company']?.toString() ?? '',
      activePrinciple: map['active_principle']?.toString() ?? '',
      package: map['package']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'product_name': productName,
      'product_company': productCompany,
      'active_principle': activePrinciple,
      'package': package,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Convert to ProductModel for compatibility
  ProductModel toProductModel() {
    return ProductModel(
      id: id,
      name: productName,
      company: productCompany,
      activePrinciple: activePrinciple,
      package: package,
      availablePackages: [package], // OCR products typically have a single package
      imageUrl: imageUrl,
      createdAt: createdAt,
      selectedPackage: package,
    );
  }
}