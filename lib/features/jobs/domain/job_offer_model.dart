class JobOffer {
  final String id;
  final String userId;
  final String? userName;
  final String? userPhotoUrl;
  final String title;
  final String description;
  final String phone;
  final String status;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobOffer({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhotoUrl,
    required this.title,
    required this.description,
    required this.phone,
    required this.status,
    required this.viewsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    return JobOffer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userPhotoUrl: json['user_photo'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
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
      'user_photo': userPhotoUrl,
      'title': title,
      'description': description,
      'phone': phone,
      'status': status,
      'views_count': viewsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  JobOffer copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? title,
    String? description,
    String? phone,
    String? status,
    int? viewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobOffer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
