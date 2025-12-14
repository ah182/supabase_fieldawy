// ============================================================================
// 🌟 REVIEW SYSTEM - نظام التقييمات والمراجعات
// ============================================================================
// ملف شامل يحتوي على:
// - Models (Freezed)
// - Service (Business Logic)
// - Providers (Riverpod)
// - Widgets (UI Components)
// - Screens (Pages)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/profile/application/blocking_service.dart';

// ============================================================================
// 📦 MODELS
// ============================================================================

/// نموذج طلب التقييم
class ReviewRequestModel {
  final String id;
  final String productId;
  final String productType;
  final String productName;
  final String? productImage;
  final String? productPackage;
  final String requestedBy;
  final String requesterName;
  final String? requesterPhoto;
  final String? requesterRole;
  final String status;
  final int commentsCount;
  final int totalReviewsCount;
  final double? avgRating;
  final DateTime requestedAt;
  final DateTime? closedAt;
  final String? closedReason;
  final bool isCommentsFull;
  final bool canAddComment;
  final String? requestComment; // جديد: تعليق طالب التقييم

  ReviewRequestModel({
    required this.id,
    required this.productId,
    required this.productType,
    required this.productName,
    this.productImage,
    this.productPackage,
    required this.requestedBy,
    required this.requesterName,
    this.requesterPhoto,
    this.requesterRole,
    required this.status,
    required this.commentsCount,
    required this.totalReviewsCount,
    this.avgRating,
    required this.requestedAt,
    this.closedAt,
    this.closedReason,
    required this.isCommentsFull,
    required this.canAddComment,
    this.requestComment, // جديد: تعليق طالب التقييم
  });

  factory ReviewRequestModel.fromJson(Map<String, dynamic> json) {
    return ReviewRequestModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productType: json['product_type'] as String? ?? 'product',
      productName: json['product_name'] as String? ?? '',
      productImage: json['product_image'] as String?,
      productPackage: json['product_package'] as String?,
      requestedBy: json['requested_by'] as String,
      requesterName: json['requester_name'] as String? ?? '',
      requesterPhoto: json['requester_photo'] as String?,
      requesterRole: json['requester_role'] as String?,
      status: json['status'] as String? ?? 'active',
      commentsCount: json['comments_count'] as int? ?? 0,
      totalReviewsCount: json['total_reviews_count'] as int? ?? 0,
      avgRating: json['avg_rating'] != null
          ? (json['avg_rating'] as num).toDouble()
          : null,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      closedReason: json['closed_reason'] as String?,
      isCommentsFull: json['is_comments_full'] as bool? ?? false,
      canAddComment: json['can_add_comment'] as bool? ?? true,
      requestComment: json['request_comment'] as String?, // جديد: تعليق طالب التقييم
    );
  }
}

/// نموذج التقييم
class ProductReviewModel {
  final String id;
  final String reviewRequestId;
  final String productId;
  final String productType;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int rating;
  final String? comment;
  final bool hasComment;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final int unhelpfulCount;
  final bool currentUserVotedHelpful;
  final bool currentUserVotedUnhelpful;
  final DateTime createdAt;
  final String? productName;

  ProductReviewModel({
    required this.id,
    required this.reviewRequestId,
    required this.productId,
    required this.productType,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    this.comment,
    required this.hasComment,
    this.isVerifiedPurchase = false,
    this.helpfulCount = 0,
    this.unhelpfulCount = 0,
    this.currentUserVotedHelpful = false,
    this.currentUserVotedUnhelpful = false,
    required this.createdAt,
    this.productName,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewModel(
      id: json['id'] as String,
      reviewRequestId: json['review_request_id'] as String,
      productId: json['product_id'] as String,
      productType: json['product_type'] as String? ?? 'product',
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? '',
      userPhoto: json['user_photo'] as String?,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      hasComment: json['has_comment'] as bool? ?? false,
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      unhelpfulCount: json['unhelpful_count'] as int? ?? 0,
      currentUserVotedHelpful:
          json['current_user_voted_helpful'] as bool? ?? false,
      currentUserVotedUnhelpful:
          json['current_user_voted_unhelpful'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['product_name'] as String?,
    );
  }
}

// ============================================================================
// 🔧 SERVICE
// ============================================================================

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========================================
  // CREATE REVIEW REQUEST
  // ========================================
  Future<Map<String, dynamic>> createReviewRequest({
    required String productId,
    String productType = 'product',
    String? requestComment, // جديد: تعليق طالب التقييم
  }) async {
    try {
      return {
        'success': false,
        'error': 'invalid_response',
        'message': 'invalid_response_from_server'.tr()
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // ADD REVIEW
  // ========================================
  Future<Map<String, dynamic>> addProductReview({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _supabase.rpc(
        'add_product_review',
        params: {
          'p_request_id': requestId,
          'p_rating': rating,
          'p_comment': comment,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {
        'success': false,
        'error': 'invalid_response',
        'message': 'invalid_response_from_server'.tr()
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // VOTE HELPFUL
  // ========================================
  Future<Map<String, dynamic>> voteReviewHelpful({
    required String reviewId,
    required bool isHelpful,
  }) async {
    try {
      final response = await _supabase.rpc(
        'vote_review_helpful',
        params: {
          'p_review_id': reviewId,
          'p_is_helpful': isHelpful,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {'success': true, 'message': 'تم تسجيل تصويتك'.tr()};
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // DELETE MY REVIEW
  // ========================================
  Future<Map<String, dynamic>> deleteMyReview(String reviewId) async {
    try {
      final response = await _supabase.rpc(
        'delete_my_review',
        params: {'p_review_id': reviewId},
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {'success': true, 'message': 'تم حذف التقييم'.tr()};
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // REPORT REVIEW
  // ========================================
  Future<Map<String, dynamic>> reportReview({
    required String reviewId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await _supabase.rpc(
        'report_review',
        params: {
          'p_review_id': reviewId,
          'p_reason': reason,
          'p_description': description,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {'success': true, 'message': 'تم إرسال البلاغ بنجاح'.tr()};
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // DELETE MY REVIEW REQUEST
  // ========================================
  Future<Map<String, dynamic>> deleteMyReviewRequest(String requestId) async {
    try {
      final response = await _supabase.rpc(
        'delete_my_review_request',
        params: {'p_request_id': requestId},
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      return {'success': true, 'message': 'تم حذف طلب التقييم'.tr()};
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'unexpected_error'.tr(),
      };
    }
  }

  // ========================================
  // GET ACTIVE REVIEW REQUESTS
  // ========================================
  Future<List<ReviewRequestModel>> getActiveReviewRequests({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // استخدام RPC function بدلاً من view
      final response = await _supabase.rpc('get_active_review_requests');

      if (response is List) {
        return response
            .map((json) => ReviewRequestModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching active review requests: $e');
      return [];
    }
  }

  // ========================================
  // GET MY REVIEW REQUESTS
  // ========================================
  Future<List<ReviewRequestModel>> getMyReviewRequests() async {
    try {
      final response = await _supabase
          .from('my_review_requests')
          .select()
          .order('requested_at', ascending: false);

      return (response as List)
          .map((json) => ReviewRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching my review requests: $e');
      return [];
    }
  }

  // ========================================
  // GET PRODUCT REVIEWS
  // ========================================
  Future<List<ProductReviewModel>> getProductReviews({
    required String productId,
    String productType = 'product',
    String sortBy = 'recent',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_product_reviews',
        params: {
          'p_product_id': productId,
          'p_product_type': productType,
          'p_sort_by': sortBy,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final reviews = (response as List)
          .map((json) {
            print('📦 Review from DB: id=${json['id']}, helpful=${json['helpful_count']}, unhelpful=${json['unhelpful_count']}');
            print('   👤 User: name=${json['user_name']}, photo=${json['user_photo']}');
            return ProductReviewModel.fromJson(json);
          })
          .toList();
      
      print('✅ Total reviews fetched: ${reviews.length}');
      return reviews;
    } catch (e) {
      print('Error fetching product reviews: $e');
      return [];
    }
  }

  // ========================================
  // GET REQUEST BY PRODUCT
  // ========================================
  Future<ReviewRequestModel?> getRequestByProduct({
    required String productId,
    String productType = 'product',
  }) async {
    try {
      final response = await _supabase
          .from('review_requests_with_details')
          .select()
          .eq('product_id', productId)
          .eq('product_type', productType)
          .maybeSingle();

      if (response == null) return null;
      return ReviewRequestModel.fromJson(response);
    } catch (e) {
      print('Error fetching request by product: $e');
      return null;
    }
  }

  // ========================================
  // CHECK IF USER REVIEWED
  // ========================================
  Future<ProductReviewModel?> getUserReview({
    required String requestId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews_with_details')
          .select()
          .eq('review_request_id', requestId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProductReviewModel.fromJson(response);
    } catch (e) {
      print('Error fetching user review: $e');
      return null;
    }
  }
}

// ============================================================================
// 🎯 PROVIDERS
// ============================================================================

/// Service Provider
final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

/// Active Review Requests Provider
final activeReviewRequestsProvider =
    FutureProvider<List<ReviewRequestModel>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getActiveReviewRequests(limit: 50);
});

/// My Review Requests Provider
final myReviewRequestsProvider =
    FutureProvider<List<ReviewRequestModel>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getMyReviewRequests();
});

/// Product Reviews Provider (بناءً على product_id)
final productReviewsProvider = FutureProvider.family<List<ProductReviewModel>,
    ({String productId, String productType})>(
  (ref, params) async {
    final service = ref.read(reviewServiceProvider);
    
    // Get all reviews
    final reviews = await service.getProductReviews(
      productId: params.productId,
      productType: params.productType,
    );

    // Filter blocked users
    final blockingService = ref.read(blockingServiceProvider);
    final blockedUsers = await blockingService.getBlockedUsers();
    
    // Return filtered list
    return reviews.where((review) => !blockedUsers.contains(review.userId)).toList();
  },
);

/// Request by Product Provider
final requestByProductProvider = FutureProvider.family<ReviewRequestModel?,
    ({String productId, String productType})>(
  (ref, params) async {
    final service = ref.read(reviewServiceProvider);
    return service.getRequestByProduct(
      productId: params.productId,
      productType: params.productType,
    );
  },
);

// ============================================================================
// 🎨 WIDGETS
// ============================================================================

// ========================================
// RATING STARS WIDGET
// ========================================
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  final bool showNumber;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.color,
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          if (index < rating.floor()) {
            return Icon(Icons.star, size: size, color: starColor);
          } else if (index < rating) {
            return Icon(Icons.star_half, size: size, color: starColor);
          } else {
            return Icon(Icons.star_border, size: size, color: starColor);
          }
        }),
        if (showNumber) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

// ========================================
// INTERACTIVE RATING INPUT
// ========================================
class RatingInput extends StatefulWidget {
  final int initialRating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  const RatingInput({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.size = 32,
  });

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _rating = starIndex);
            widget.onRatingChanged(starIndex);
          },
          child: Icon(
            starIndex <= _rating ? Icons.star : Icons.star_border,
            size: widget.size,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}

// ========================================
// REVIEW REQUEST CARD
// ========================================
class ReviewRequestCard extends StatelessWidget {
  final ReviewRequestModel request;
  final VoidCallback? onTap;

  const ReviewRequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Product name + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.productName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(request.status, colorScheme),
                ],
              ),
              const SizedBox(height: 8),

              // Requester info
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: request.requesterPhoto != null
                        ? CachedNetworkImageProvider(request.requesterPhoto!)
                        : null,
                    child: request.requesterPhoto == null
                        ? const Icon(Icons.person, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    request.requesterName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(request.requestedAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats
              Row(
                children: [
                  if (request.avgRating != null) ...[
                    RatingStars(
                      rating: request.avgRating!,
                      size: 16,
                      showNumber: true,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.rate_review,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${request.totalReviewsCount} تقييم',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${request.commentsCount}/5 تعليقات',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),

              // Progress bar for comments
              if (request.commentsCount > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: request.commentsCount / 5,
                  backgroundColor: colorScheme.surfaceVariant,
                  color: request.isCommentsFull
                      ? Colors.green
                      : colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ColorScheme colorScheme) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'نشط' : 'مغلق',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

// ========================================
// PRODUCT REVIEW CARD
// ========================================
class ProductReviewCard extends ConsumerWidget {
  final ProductReviewModel review;

  const ProductReviewCard({
    super.key,
    required this.review,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final service = ref.read(reviewServiceProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMyReview = currentUserId != null && currentUserId == review.userId;
    
    print('🔍 Debug Review Card:');
    print('   - Review Owner ID: ${review.userId}');
    print('   - Current User ID: $currentUserId');
    print('   - Is My Review? $isMyReview (Report button hidden if true)');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row: User Info + Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userPhoto != null
                      ? CachedNetworkImageProvider(review.userPhoto!)
                      : null,
                  child: review.userPhoto == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                // User Name and Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              review.userName,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.isVerifiedPurchase) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Button (Three Dots)
                if (isMyReview)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      tooltip: 'خيارات',
                      onSelected: (value) {
                        if (value == 'delete') {
                          _confirmDeleteReview(context, ref, review.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف التقييم',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // 2. Rating Stars
            RatingStars(rating: review.rating.toDouble()),

            // 3. Comment
            if (review.hasComment && review.comment != null) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: textTheme.bodyMedium,
              ),
            ],

            // 4. Actions (Helpful & Report)
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await service.voteReviewHelpful(
                      reviewId: review.id,
                      isHelpful: true,
                    );
                    ref.invalidate(productReviewsProvider);
                  },
                  icon: Icon(
                    review.currentUserVotedHelpful
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 18,
                  ),
                  label: Text(
                    'مفيد (${review.helpfulCount})',
                    style: textTheme.bodySmall,
                  ),
                ),
                // Report Button
                TextButton.icon(
                  onPressed: isMyReview 
                      ? null 
                      : () => _showReportDialog(context, ref, review.id),
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 18, 
                    color: isMyReview ? Colors.grey.withOpacity(0.3) : Colors.red,
                  ),
                  label: Text(
                    'إبلاغ',
                    style: textTheme.bodySmall?.copyWith(
                      color: isMyReview ? Colors.grey.withOpacity(0.3) : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReview(BuildContext context, WidgetRef ref, String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('هل أنت متأكد من أنك تريد حذف تقييمك؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = ref.read(reviewServiceProvider);
      await service.deleteMyReview(reviewId);
      ref.invalidate(productReviewsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف التقييم بنجاح')),
        );
      }
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref, String reviewId) {
    final reasons = [
      'محتوى غير لائق / مسيء',
      'رسائل مزعجة (Spam)',
      'معلومات مضللة',
      'تحرش أو تنمر',
      'أخرى',
    ];
    String selectedReason = reasons[0];
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('reviews_feature.report_content'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('reviews_feature.report_subtitle'.tr()),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'reviews_feature.report_reason_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedReason = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'reviews_feature.report_details'.tr(),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('reviews_feature.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('reviews_feature.sending_report'.tr())),
                );

                final service = ref.read(reviewServiceProvider);
                final result = await service.reportReview(
                  reviewId: reviewId,
                  reason: selectedReason,
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                );

                if (context.mounted) {
                   if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('reviews_feature.report_success'.tr()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'reviews_feature.report_error'.tr()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text('reviews_feature.submit_report'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

// ============================================================================
// 📱 SCREENS
// ============================================================================

// ========================================
// 1. ACTIVE REVIEW REQUESTS SCREEN
// ========================================
class ActiveReviewRequestsScreen extends ConsumerWidget {
  const ActiveReviewRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(activeReviewRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التقييم'),
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('لا توجد طلبات تقييم حالياً'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeReviewRequestsProvider);
            },
            child: ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return ReviewRequestCard(
                  request: request,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductReviewsScreen(request: request),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('حدث خطأ: $error'),
        ),
      ),
    );
  }
}

// ========================================
// 2. PRODUCT REVIEWS SCREEN
// ========================================
class ProductReviewsScreen extends ConsumerStatefulWidget {
  final ReviewRequestModel request;

  const ProductReviewsScreen({
    super.key,
    required this.request,
  });

  @override
  ConsumerState<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends ConsumerState<ProductReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(productReviewsProvider((
      productId: widget.request.productId,
      productType: widget.request.productType,
    )));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.request.productName),
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            child: Column(
              children: [
                if (widget.request.avgRating != null) ...[
                  Text(
                    widget.request.avgRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  RatingStars(rating: widget.request.avgRating!, size: 24),
                  const SizedBox(height: 8),
                ],
                Text(
                  '${widget.request.totalReviewsCount} تقييم',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                if (!widget.request.isCommentsFull) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${widget.request.commentsCount}/5 تعليقات',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Reviews List
          Expanded(
            child: reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return const Center(
                    child: Text('لا توجد تقييمات بعد'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(productReviewsProvider);
                  },
                  child: ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      return ProductReviewCard(review: reviews[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('حدث خطأ: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAddReviewButton(context),
    );
  }

  Widget? _buildAddReviewButton(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return null;

    // Check if user already reviewed
    final reviewsAsync = ref.watch(productReviewsProvider((
      productId: widget.request.productId,
      productType: widget.request.productType,
    )));

    return reviewsAsync.maybeWhen(
      data: (reviews) {
        final userReview =
            reviews.where((r) => r.userId == currentUserId).firstOrNull;
        if (userReview != null) return null; // Already reviewed

        return FloatingActionButton.extended(
          onPressed: () => _showAddReviewDialog(context),
          icon: const Icon(Icons.rate_review),
          label: const Text('إضافة تقييم'),
        );
      },
      orElse: () => null,
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    int rating = 0;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أضف تقييمك',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Center(
              child: RatingInput(
                onRatingChanged: (value) => rating = value,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.request.isCommentsFull) ...[
              TextField(
                controller: commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك (اختياري)',
                  border: const OutlineInputBorder(),
                  helperText:
                      'التعليقات النصية محدودة بـ5 تعليقات (${widget.request.commentsCount}/5)',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم الوصول للحد الأقصى من التعليقات. يمكنك إضافة تقييم بالنجوم فقط',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (rating == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('reviews_feature.rating_required'.tr()),
                          ),
                        );
                        return;
                      }

                      final service = ref.read(reviewServiceProvider);
                      final result = await service.addProductReview(
                        requestId: widget.request.id,
                        rating: rating,
                        comment: commentController.text.trim().isEmpty
                            ? null
                            : commentController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('reviews_feature.review_added'.tr()),
                            ),
                          );
                          // Refresh data
                          ref.invalidate(productReviewsProvider);
                          ref.invalidate(activeReviewRequestsProvider);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ??
                                  'reviews_feature.add_review_error_generic'.tr()),
                            ),
                          );
                        }
                      }
                    },
                    child: Text('reviews_feature.send'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ========================================
// 3. CREATE REVIEW REQUEST BUTTON
// ========================================
/// يستخدم في صفحة المنتج
class CreateReviewRequestButton extends ConsumerWidget {
  final String productId;
  final String productType;

  const CreateReviewRequestButton({
    super.key,
    required this.productId,
    this.productType = 'product',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(requestByProductProvider((
      productId: productId,
      productType: productType,
    )));

    return requestAsync.when(
      data: (request) {
        if (request != null) {
          // Request exists
          return OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductReviewsScreen(request: request),
                ),
              );
            },
            icon: const Icon(Icons.rate_review),
            label: Text('عرض التقييمات (${request.totalReviewsCount})'),
          );
        }

        // No request yet - can create
        return ElevatedButton.icon(
          onPressed: () => _createRequest(context, ref),
          icon: const Icon(Icons.add_comment),
          label: const Text('طلب تقييم للمنتج'),
        );
      },
      loading: () => const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => const SizedBox(),
    );
  }

  Future<void> _createRequest(BuildContext context, WidgetRef ref) async {
    final service = ref.read(reviewServiceProvider);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reviews_feature.add_request_title'.tr()),
        content: Text(
          'reviews_feature.create_request_confirmation_message'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('reviews_feature.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('reviews_feature.confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await service.createReviewRequest(
      productId: productId,
      productType: productType,
    );

    if (context.mounted) {
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reviews_feature.create_success'.tr())),
        );
        // Refresh data
        ref.invalidate(requestByProductProvider);
        ref.invalidate(activeReviewRequestsProvider);
      } else {
        // Show error
        String errorMessage = 'reviews_feature.create_request_error_generic'.tr();
        if (result['error'] == 'product_already_requested') {
          errorMessage = 'reviews_feature.product_already_requested'.tr();
        } else if (result['error'] == 'weekly_limit_exceeded') {
          errorMessage = 'reviews_feature.weekly_limit'.tr();
        } else if (result['message'] != null) {
          errorMessage = result['message'];
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }
}

// ============================================================================
// نهاية الملف
// ============================================================================
