/// Post Model for Social Posts System
/// نموذج البوست لنظام المنشورات

class PostModel {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // User info (joined from users table)
  final String? userName;
  final String? userPhoto;
  final String? userRole;

  // Counts
  final int likesCount;
  final int commentsCount;

  // Current user's interaction
  final bool isLikedByMe;
  final bool isMine;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userPhoto,
    this.userRole,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.isMine = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      userName: json['user_name'] as String?,
      userPhoto: json['user_photo'] as String?,
      userRole: json['user_role'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      isMine: currentUserId != null && json['user_id'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
    };
  }

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      content: content,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userName: userName,
      userPhoto: userPhoto,
      userRole: userRole,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isMine: isMine,
    );
  }
}
