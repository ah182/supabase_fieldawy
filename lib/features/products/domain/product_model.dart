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
    );
  }
}