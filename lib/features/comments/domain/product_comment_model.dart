class ProductComment {
  final String id;
  final String productId;
  final String distributorId;
  final String userId;
  final String content;
  final int likesCount;
  final int dislikesCount;
  final DateTime createdAt;
  final String? userName;
  final String? userPhoto;
  final String? userRole;
  final bool isMine;
  final String? myInteraction; // 'like', 'dislike', or null

  ProductComment({
    required this.id,
    required this.productId,
    required this.distributorId,
    required this.userId,
    required this.content,
    required this.likesCount,
    required this.dislikesCount,
    required this.createdAt,
    this.userName,
    this.userPhoto,
    this.userRole,
    this.isMine = false,
    this.myInteraction,
  });

  factory ProductComment.fromJson(Map<String, dynamic> json) {
    return ProductComment(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      distributorId: json['distributor_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      likesCount: json['likes_count'] as int? ?? 0,
      dislikesCount: json['dislikes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userPhoto: json['user_photo'] as String?,
      userRole: json['user_role'] as String?,
      isMine: json['is_mine'] as bool? ?? false,
      myInteraction: json['my_interaction'] as String?,
    );
  }

  ProductComment copyWith({
    String? content,
    int? likesCount,
    int? dislikesCount,
    String? myInteraction,
  }) {
    return ProductComment(
      id: id,
      productId: productId,
      distributorId: distributorId,
      userId: userId,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      createdAt: createdAt,
      userName: userName,
      userPhoto: userPhoto,
      userRole: userRole,
      isMine: isMine,
      myInteraction: myInteraction ?? this.myInteraction,
    );
  }
}
