class Offer {
  final String id;
  final String productId;
  final bool isOcr;
  final String userId;
  final double price;
  final DateTime expirationDate;
  final String? description;
  final String? package;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Optional fields for joined data
  final String? productName;
  final String? userName;
  final String? imageUrl;

  Offer({
    required this.id,
    required this.productId,
    required this.isOcr,
    required this.userId,
    required this.price,
    required this.expirationDate,
    this.description,
    this.package,
    required this.createdAt,
    this.updatedAt,
    this.productName,
    this.userName,
    this.imageUrl,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'].toString(),
      productId: json['product_id'].toString(),
      isOcr: json['is_ocr'] as bool? ?? false,
      userId: json['user_id'].toString(),
      price: (json['price'] as num).toDouble(),
      expirationDate: DateTime.parse(json['expiration_date'] as String),
      description: json['description'] as String?,
      package: json['package'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      productName: json['product_name'] as String?,
      userName: json['user_name'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'is_ocr': isOcr,
      'user_id': userId,
      'price': price,
      'expiration_date': expirationDate.toIso8601String(),
      'description': description,
      'package': package,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (productName != null) 'product_name': productName,
      if (userName != null) 'user_name': userName,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expirationDate);

  Offer copyWith({
    String? id,
    String? productId,
    bool? isOcr,
    String? userId,
    double? price,
    DateTime? expirationDate,
    String? description,
    String? package,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    String? userName,
    String? imageUrl,
  }) {
    return Offer(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      isOcr: isOcr ?? this.isOcr,
      userId: userId ?? this.userId,
      price: price ?? this.price,
      expirationDate: expirationDate ?? this.expirationDate,
      description: description ?? this.description,
      package: package ?? this.package,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt,
      productName: productName ?? this.productName,
      userName: userName ?? this.userName,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
