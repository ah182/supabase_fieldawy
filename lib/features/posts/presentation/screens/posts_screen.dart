import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/posts/application/posts_provider.dart';
import 'package:fieldawy_store/features/posts/presentation/widgets/post_card.dart';
import 'package:fieldawy_store/features/posts/presentation/screens/create_post_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/posts/application/unseen_posts_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch posts on mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(postsProvider.notifier).fetchPosts(refresh: true);

      // Mark posts as seen when entering the screen
      await markPostsAsSeen();
      if (mounted) {
        ref.invalidate(unseenPostsProvider);
      }
    });

    // Listen for scroll to load more
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(postsProvider.notifier);
      if (!notifier.isLoading && notifier.hasMore) {
        notifier.fetchPosts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final currentUser = ref.watch(userDataProvider);
    final isAdmin = currentUser.valueOrNull?.role == 'admin';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Newspaper-icon.png",
                width: 20,
                height: 20,
                color: Colors.white,
                placeholder: (context, url) => const FaIcon(
                    FontAwesomeIcons.newspaper,
                    color: Colors.white,
                    size: 20),
                errorWidget: (context, url, error) => const FaIcon(
                    FontAwesomeIcons.newspaper,
                    color: Colors.white,
                    size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.locale.languageCode == 'ar'
                  ? 'منشورات الأطباء'
                  : 'Doctors Posts',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: postsAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, st) => _buildErrorState(error),
        data: (posts) {
          if (posts.isEmpty) {
            return _buildEmptyState(theme);
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(postsProvider.notifier).fetchPosts(refresh: true),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: posts.length + 1, // +1 for loading indicator
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  // Loading more indicator
                  final notifier = ref.read(postsProvider.notifier);
                  if (notifier.hasMore && notifier.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SizedBox.shrink();
                }

                return PostCard(
                  post: posts[index],
                  isAdmin: isAdmin,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _buildCreatePostFAB(context, theme),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => _buildPostSkeleton(),
    );
  }

  Widget _buildPostSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CachedNetworkImage(
            imageUrl:
                "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Font_Awesome_5_solid_exclamation-circle.svg/512px-Font_Awesome_5_solid_exclamation-circle.svg.png",
            width: 64,
            height: 64,
            color: Colors.red[300],
            placeholder: (context, url) => FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 64,
                color: Colors.red[300]),
            errorWidget: (context, url, error) => FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 64,
                color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          Text(
            context.locale.languageCode == 'ar'
                ? 'حدث خطأ'
                : 'An error occurred',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(postsProvider.notifier).fetchPosts(refresh: true),
            icon: CachedNetworkImage(
              imageUrl:
                  "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Rotate-Right-icon.png",
              width: 18,
              height: 18,
              color: Theme.of(context).colorScheme.primary,
              placeholder: (context, url) =>
                  const FaIcon(FontAwesomeIcons.rotateRight, size: 18),
              errorWidget: (context, url, error) =>
                  const FaIcon(FontAwesomeIcons.rotateRight, size: 18),
            ),
            label: Text(context.locale.languageCode == 'ar'
                ? 'إعادة المحاولة'
                : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CachedNetworkImage(
              imageUrl:
                  "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Newspaper-icon.png",
              width: 64,
              height: 64,
              color: theme.colorScheme.primary,
              placeholder: (context, url) => FaIcon(
                FontAwesomeIcons.newspaper,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              errorWidget: (context, url, error) => FaIcon(
                FontAwesomeIcons.newspaper,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.locale.languageCode == 'ar'
                ? 'لا توجد منشورات بعد'
                : 'No posts yet',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.locale.languageCode == 'ar'
                ? 'كن أول من ينشر!'
                : 'Be the first to post!',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreatePost(context),
            icon: CachedNetworkImage(
              imageUrl:
                  "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png",
              width: 18,
              height: 18,
              color: Colors.white,
              placeholder: (context, url) =>
                  const FaIcon(FontAwesomeIcons.plus, size: 18),
              errorWidget: (context, url, error) =>
                  const FaIcon(FontAwesomeIcons.plus, size: 18),
            ),
            label: Text(context.locale.languageCode == 'ar'
                ? 'إنشاء منشور'
                : 'Create Post'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostFAB(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _navigateToCreatePost(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: CachedNetworkImage(
          imageUrl:
              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Pen-icon.png",
          width: 24,
          height: 24,
          color: Colors.white,
          placeholder: (context, url) =>
              const FaIcon(FontAwesomeIcons.pen, color: Colors.white),
          errorWidget: (context, url, error) =>
              const FaIcon(FontAwesomeIcons.pen, color: Colors.white),
        ),
        label: Text(
          context.locale.languageCode == 'ar' ? 'نشر' : 'Post',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _navigateToCreatePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
  }
}
