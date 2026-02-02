import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/posts/domain/post_model.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:path_provider/path_provider.dart';

/// Provider for posts list with pagination and caching
final postsProvider =
    StateNotifierProvider<PostsNotifier, AsyncValue<List<PostModel>>>((ref) {
  return PostsNotifier(ref);
});

class PostsNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  final Ref ref;

  PostsNotifier(this.ref) : super(const AsyncValue.loading());

  final _supabase = Supabase.instance.client;
  static const int _pageSize = 10;
  static const String _cacheKey = 'posts_feed_v1';
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  /// Fetch posts with pagination and caching
  Future<void> fetchPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    _isLoading = true;

    if (refresh) {
      _currentPage = 0;
      _hasMore = true;

      // Try to load from cache first for instant display
      final cache = ref.read(cachingServiceProvider);
      final cachedPosts = await cache.get<List<dynamic>>(_cacheKey);
      if (cachedPosts != null) {
        try {
          final posts = cachedPosts
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>,
                  currentUserId: _currentUserId))
              .toList();
          state = AsyncValue.data(posts);
        } catch (_) {
          state = const AsyncValue.loading();
        }
      } else {
        state = const AsyncValue.loading();
      }
    }

    try {
      await NetworkGuard.execute(() async {
        // First fetch posts with likes only (no user join)
        final response = await _supabase
            .from('posts')
            .select('''
              *,
              post_likes (user_id)
            ''')
            .order('created_at', ascending: false)
            .range(
                _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

        final List<PostModel> newPosts = [];

        for (final json in response as List) {
          final likes = json['post_likes'] as List? ?? [];
          final likesCount = likes.length;
          final isLikedByMe =
              likes.any((like) => like['user_id'] == _currentUserId);

          // Fetch user info separately
          String? userName;
          String? userPhoto;
          String? userRole;

          try {
            final userResponse = await _supabase
                .from('users')
                .select('display_name, photo_url, role')
                .eq('id', json['user_id'])
                .maybeSingle();

            if (userResponse != null) {
              userName = userResponse['display_name'];
              userPhoto = userResponse['photo_url'];
              userRole = userResponse['role'];
            }
          } catch (_) {}

          // Get comments count
          final countResponse = await _supabase
              .from('post_comments')
              .select()
              .eq('post_id', json['id'])
              .count(CountOption.exact);

          newPosts.add(PostModel.fromJson({
            ...json,
            'user_name': userName,
            'user_photo': userPhoto,
            'user_role': userRole,
            'likes_count': likesCount,
            'comments_count': countResponse.count,
            'is_liked_by_me': isLikedByMe,
          }, currentUserId: _currentUserId));
        }

        _hasMore = newPosts.length >= _pageSize;
        _currentPage++;

        if (refresh) {
          state = AsyncValue.data(newPosts);

          // Save to cache
          final cache = ref.read(cachingServiceProvider);
          cache.set(
            _cacheKey,
            newPosts.map((p) => _postToCache(p)).toList(),
            duration: const Duration(minutes: 10),
          );
        } else {
          final currentPosts = state.valueOrNull ?? [];
          state = AsyncValue.data([...currentPosts, ...newPosts]);
        }
      });
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Convert post to cacheable map
  Map<String, dynamic> _postToCache(PostModel post) {
    return {
      'id': post.id,
      'user_id': post.userId,
      'content': post.content,
      'image_url': post.imageUrl,
      'created_at': post.createdAt.toIso8601String(),
      'updated_at': post.updatedAt?.toIso8601String(),
      'user_name': post.userName,
      'user_photo': post.userPhoto,
      'user_role': post.userRole,
      'likes_count': post.likesCount,
      'comments_count': post.commentsCount,
      'is_liked_by_me': post.isLikedByMe,
    };
  }

  /// Compress image before upload
  Future<File?> _compressImage(XFile image) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 70, // 70% quality
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      // If compression fails, return original
      return File(image.path);
    }
  }

  /// Create a new post with image compression
  Future<bool> createPost({
    required String content,
    XFile? image,
  }) async {
    try {
      print('📝 Creating post...');
      print('📝 User ID: $_currentUserId');
      print('📝 Content: $content');
      print('📝 Has image: ${image != null}');

      String? imageUrl;

      // Compress and upload image if provided
      if (image != null) {
        print('🖼️ Compressing image...');
        final compressedFile = await _compressImage(image);
        if (compressedFile != null) {
          print('✅ Image compressed: ${compressedFile.path}');
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'posts/$fileName';

          print('📤 Uploading image to: $filePath');
          await _supabase.storage
              .from('posts')
              .upload(filePath, compressedFile);
          print('✅ Image uploaded successfully');

          imageUrl = _supabase.storage.from('posts').getPublicUrl(filePath);
          print('🔗 Image URL: $imageUrl');
        } else {
          print('❌ Image compression failed');
        }
      }

      print('💾 Inserting post into database...');
      print(
          '💾 Data: {user_id: $_currentUserId, content: $content, image_url: $imageUrl}');

      await _supabase.from('posts').insert({
        'user_id': _currentUserId,
        'content': content,
        'image_url': imageUrl,
      });
      print('✅ Post inserted successfully');

      // Refresh to get the new post and update cache
      print('🔄 Refreshing posts...');
      await fetchPosts(refresh: true);
      print('✅ Posts refreshed');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error creating post: $e');
      print('📋 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update an existing post
  Future<bool> updatePost({
    required String postId,
    required String content,
    XFile? image, // New image if selected
    bool removeImage = false, // To handle image removal if needed
  }) async {
    try {
      print('📝 Updating post $postId...');

      final updates = <String, dynamic>{
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle image update
      if (image != null) {
        print('🖼️ Compressing new image...');
        final compressedFile = await _compressImage(image);
        if (compressedFile != null) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'posts/$fileName';

          await _supabase.storage
              .from('posts')
              .upload(filePath, compressedFile);
          final imageUrl =
              _supabase.storage.from('posts').getPublicUrl(filePath);
          updates['image_url'] = imageUrl;
        }
      } else if (removeImage) {
        updates['image_url'] = null;
      }

      await _supabase.from('posts').update(updates).eq('id', postId);

      // Refresh to get updates
      await fetchPosts(refresh: true);
      return true;
    } catch (e) {
      print('❌ Error updating post: $e');
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(String postId) async {
    try {
      await _supabase.from('posts').delete().eq('id', postId);

      // Remove from local state
      final currentPosts = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentPosts.where((p) => p.id != postId).toList(),
      );

      // Invalidate cache
      final cache = ref.read(cachingServiceProvider);
      cache.invalidate(_cacheKey);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Report a post
  Future<bool> reportPost(String postId, String reason) async {
    try {
      await _supabase.from('post_reports').insert({
        'post_id': postId,
        'reporter_id': _currentUserId,
        'reason': reason,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId) async {
    final currentPosts = state.valueOrNull ?? [];
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final wasLiked = post.isLikedByMe;

    // Optimistic update
    final updatedPost = post.copyWith(
      isLikedByMe: !wasLiked,
      likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
    );
    final updatedPosts = [...currentPosts];
    updatedPosts[postIndex] = updatedPost;
    state = AsyncValue.data(updatedPosts);

    try {
      if (wasLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', _currentUserId!);
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': _currentUserId,
        });
      }
    } catch (e) {
      // Revert on error
      final List<PostModel> revertedPosts = [...state.valueOrNull ?? []];
      revertedPosts[postIndex] = post;
      state = AsyncValue.data(revertedPosts);
    }
  }

  /// Update comment count for a post
  void updateCommentCount(String postId, int delta) {
    final currentPosts = state.valueOrNull ?? [];
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final updatedPost = post.copyWith(
      commentsCount: post.commentsCount + delta,
    );
    final updatedPosts = [...currentPosts];
    updatedPosts[postIndex] = updatedPost;
    state = AsyncValue.data(updatedPosts);
  }
}
