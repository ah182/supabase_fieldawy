class VetSupply {
  final String id;
  final String userId;
  final String? userName;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String phone;
  final String status;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  VetSupply({
    required this.id,
    required this.userId,
    this.userName,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.phone,
    required this.status,
    required this.viewsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VetSupply.fromJson(Map<String, dynamic> json) {
    return VetSupply(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      userName: json['user_name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String,
      phone: json['phone'] as String,
      status: json['status'] as String? ?? 'active',
      viewsCount: json['views_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'phone': phone,
      'status': status,
      'views_count': viewsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  VetSupply copyWith({
    String? id,
    String? userId,
    String? userName,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? phone,
    String? status,
    int? viewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VetSupply(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
