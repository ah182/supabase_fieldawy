/// Post Comment Model for Social Posts System
/// نموذج التعليق مع دعم الردود المتداخلة

class PostCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String? parentId; // For nested replies
  final String content;
  final DateTime createdAt;

  // User info (joined from users table)
  final String? userName;
  final String? userPhoto;
  final String? userRole;

  // Current user's ownership
  final bool isMine;

  // Nested replies (populated client-side)
  final List<PostCommentModel> replies;

  PostCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userPhoto,
    this.userRole,
    this.isMine = false,
    this.replies = const [],
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    return PostCommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userPhoto: json['user_photo'] as String?,
      userRole: json['user_role'] as String?,
      isMine: currentUserId != null && json['user_id'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'user_id': userId,
      'parent_id': parentId,
      'content': content,
    };
  }

  PostCommentModel copyWithReplies(List<PostCommentModel> newReplies) {
    return PostCommentModel(
      id: id,
      postId: postId,
      userId: userId,
      parentId: parentId,
      content: content,
      createdAt: createdAt,
      userName: userName,
      userPhoto: userPhoto,
      userRole: userRole,
      isMine: isMine,
      replies: newReplies,
    );
  }
}
