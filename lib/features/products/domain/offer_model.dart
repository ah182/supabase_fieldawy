class OfferModel {
  final String? id;
  final String productId;
  final bool isOcr;
  final String userId;
  final double price;
  final String? description;
  final DateTime expirationDate;
  final DateTime? createdAt;

  OfferModel({
    this.id,
    required this.productId,
    required this.isOcr,
    required this.userId,
    required this.price,
    this.description,
    required this.expirationDate,
    this.createdAt,
  });

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    return OfferModel(
      id: map['id']?.toString(),
      productId: map['product_id']?.toString() ?? '',
      isOcr: map['is_ocr'] == true,
      userId: map['user_id']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description']?.toString(),
      expirationDate: map['expiration_date'] != null
          ? DateTime.parse(map['expiration_date'].toString())
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'is_ocr': isOcr,
      'user_id': userId,
      'price': price,
      'description': description,
      'expiration_date': expirationDate.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  OfferModel copyWith({
    String? id,
    String? productId,
    bool? isOcr,
    String? userId,
    double? price,
    String? description,
    DateTime? expirationDate,
    DateTime? createdAt,
  }) {
    return OfferModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      isOcr: isOcr ?? this.isOcr,
      userId: userId ?? this.userId,
      price: price ?? this.price,
      description: description ?? this.description,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
