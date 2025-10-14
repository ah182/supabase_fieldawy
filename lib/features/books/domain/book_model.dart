class Book {
  final String id;
  final String userId;
  final String name;
  final String author;
  final String description;
  final double price;
  final String phone;
  final String imageUrl;
  final int views;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;
  final String? userRole;

  Book({
    required this.id,
    required this.userId,
    required this.name,
    required this.author,
    required this.description,
    required this.price,
    required this.phone,
    required this.imageUrl,
    required this.views,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userRole,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      phone: json['phone'] as String,
      imageUrl: json['image_url'] as String,
      views: json['views'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userRole: json['user_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'author': author,
      'description': description,
      'price': price,
      'phone': phone,
      'image_url': imageUrl,
      'views': views,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (userRole != null) 'user_role': userRole,
    };
  }

  Book copyWith({
    String? id,
    String? userId,
    String? name,
    String? author,
    String? description,
    double? price,
    String? phone,
    String? imageUrl,
    int? views,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userRole,
  }) {
    return Book(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      author: author ?? this.author,
      description: description ?? this.description,
      price: price ?? this.price,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
    );
  }
}
