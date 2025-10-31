class Comment {
  final String id;
  final String itemId; // course_id أو book_id
  final String userId;
  final String commentText;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // بيانات المستخدم (من join)
  final String? userName;
  final String? userPhotoUrl;
  final String? userRole;

  Comment({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
    this.userRole,
  });

  factory Comment.fromJson(Map<String, dynamic> json, {String? itemIdKey}) {
    // itemIdKey يمكن أن يكون 'course_id' أو 'book_id'
    final actualItemIdKey = itemIdKey ?? 'course_id';
    
    return Comment(
      id: json['id'] as String,
      itemId: json[actualItemIdKey] as String,
      userId: json['user_id'] as String,
      commentText: json['comment_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // البيانات من join مع جدول users
      userName: json['user_name'] as String? ?? 
                json['users']?['display_name'] as String?,
      userPhotoUrl: json['user_photo_url'] as String? ?? 
                    json['users']?['photo_url'] as String?,
      userRole: json['user_role'] as String? ?? 
                json['users']?['role'] as String?,
    );
  }

  Map<String, dynamic> toJson({String? itemIdKey}) {
    final actualItemIdKey = itemIdKey ?? 'course_id';
    
    return {
      'id': id,
      actualItemIdKey: itemId,
      'user_id': userId,
      'comment_text': commentText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (userPhotoUrl != null) 'user_photo_url': userPhotoUrl,
      if (userRole != null) 'user_role': userRole,
    };
  }

  Comment copyWith({
    String? id,
    String? itemId,
    String? userId,
    String? commentText,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userPhotoUrl,
    String? userRole,
  }) {
    return Comment(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      commentText: commentText ?? this.commentText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userRole: userRole ?? this.userRole,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // دوال مساعدة لعرض الوقت بشكل جميل
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'منذ $years ${years == 1 ? 'سنة' : 'سنوات'}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'منذ $months ${months == 1 ? 'شهر' : 'أشهر'}';
    } else if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return 'الآن';
    }
  }
}
