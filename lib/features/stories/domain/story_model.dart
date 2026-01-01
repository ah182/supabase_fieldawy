import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';

class StoryModel {
  final String id;
  final String distributorId;
  final String imageUrl;
  final String? caption;
  final String? productLinkId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewsCount;
  final int likesCount;
  // بيانات الموزع (للعرض في الستوري)
  final DistributorModel? distributor;

  StoryModel({
    required this.id,
    required this.distributorId,
    required this.imageUrl,
    this.caption,
    this.productLinkId,
    required this.createdAt,
    required this.expiresAt,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.distributor,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map, {DistributorModel? distributor}) {
    return StoryModel(
      id: map['id'],
      distributorId: map['distributor_id'],
      imageUrl: map['image_url'],
      caption: map['caption'],
      productLinkId: map['product_link_id'],
      createdAt: DateTime.parse(map['created_at']),
      expiresAt: DateTime.parse(map['expires_at']),
      viewsCount: map['views_count'] ?? 0,
      likesCount: map['likes_count'] ?? 0,
      distributor: distributor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distributor_id': distributorId,
      'image_url': imageUrl,
      'caption': caption,
      'product_link_id': productLinkId,
    };
  }
}

/// كلاس لتجميع الستوريهات لكل موزع
class DistributorStoriesGroup {
  final DistributorModel distributor;
  final List<StoryModel> stories;

  DistributorStoriesGroup({
    required this.distributor,
    required this.stories,
  });
}