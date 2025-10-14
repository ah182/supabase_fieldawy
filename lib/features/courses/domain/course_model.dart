class Course {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double price;
  final String phone;
  final String imageUrl;
  final int views;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;
  final String? userRole;

  Course({
    required this.id,
    required this.userId,
    required this.title,
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

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
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
      'title': title,
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

  Course copyWith({
    String? id,
    String? userId,
    String? title,
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
    return Course(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
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
