import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/products/application/expire_drugs_provider.dart';
import 'package:fieldawy_store/features/products/application/surgical_tools_home_provider.dart';
import 'package:fieldawy_store/features/products/application/offers_home_provider.dart';
import 'package:fieldawy_store/features/home/application/search_filters_provider.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unnecessary_import
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/features/books/presentation/screens/book_details_screen.dart';
import 'package:fieldawy_store/features/books/presentation/screens/user_books_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/user_courses_screen.dart';

import 'package:fieldawy_store/features/courses/presentation/screens/course_details_screen.dart';
import 'product_dialogs.dart';

/// A reusable error view for tabs with a refresh button.
class TabErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const TabErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr()), // Assuming 'retry' key exists, otherwise fallback to "Retry"
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Courses Tab - الكورسات البيطرية
// ===================================================================
class CoursesTab extends ConsumerWidget {
  const CoursesTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(allCoursesNotifierProvider);

    return coursesAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => TabErrorView(
        message: 'courses_feature.error_occurred'.tr(),
        onRetry: () => ref.invalidate(allCoursesNotifierProvider),
      ),
      data: (courses) {
        final filteredCourses = searchQuery.isEmpty
            ? courses
            : courses.where((course) {
                final query = searchQuery.toLowerCase();
                return course.title.toLowerCase().contains(query) ||
                    course.description.toLowerCase().contains(query);
              }).toList();

        if (filteredCourses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.school_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'courses_feature.empty.no_courses_available'.tr()
                      : 'courses_feature.empty.no_results'.tr(namedArgs: {'query': searchQuery}),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                // Show refresh button also on empty state if it might be an error
                const SizedBox(height: 16),
                 TextButton.icon(
                  onPressed: () => ref.invalidate(allCoursesNotifierProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allCoursesNotifierProvider);
            // ننتظر قليلاً للتأكد من اكتمال الـ rebuild وظهور حالة التحميل
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView.builder(
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              return GestureDetector(
                onTap: () => _showCourseDialog(context, ref, course),
                child: _CourseCardHorizontal(
                  course: course,
                  searchQuery: searchQuery,
                  onTap: () => _showCourseDialog(context, ref, course),
                ),
              );
            },
            padding: const EdgeInsets.all(16.0),
          ),
        );
      },
    );
  }

  static void _showCourseDialog(BuildContext context, WidgetRef ref, dynamic course) {
    // ... (rest of the dialog code) ...
    // Using previous implementation for brevity in rewrite, ensuring all logic is kept.
    final theme = Theme.of(context);
    final distributorsAsync = ref.read(distributorsProvider);
    final owner = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == course.userId);
    final ownerName = owner?.displayName ?? course.userName ?? 'مستخدم';
    ref.read(allCoursesNotifierProvider.notifier).incrementViews(course.id);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: course.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserCoursesScreen(
                              userId: course.userId,
                              userName: ownerName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                ownerName,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      course.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatChip(
                          context: context,
                          icon: Icons.price_change,
                          label: 'courses_feature.price'.tr(),
                          value: '${NumberFormatter.formatCompact(course.price)} ${'products.currency'.tr()}',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          context: context,
                          icon: Icons.visibility,
                          label: 'courses_feature.views'.tr(),
                          value: NumberFormatter.formatCompact(course.views),
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CourseDetailsScreen(course: course),
                                ),
                              );
                            },
                            label: Text('courses_feature.course_details'.tr(),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openWhatsApp(context, course.phone);
                            },
                            icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                            label: Text(
                              'courses_feature.contact'.tr(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('courses_feature.whatsapp_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ===================================================================
// Books Tab - الكتب البيطرية
// ===================================================================
class BooksTab extends ConsumerWidget {
  const BooksTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(allBooksNotifierProvider);

    return booksAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => TabErrorView(
        message: 'books_feature.error_occurred'.tr(),
        onRetry: () => ref.invalidate(allBooksNotifierProvider),
      ),
      data: (books) {
        final filteredBooks = searchQuery.isEmpty
            ? books
            : books.where((book) {
                final query = searchQuery.toLowerCase();
                return book.name.toLowerCase().contains(query) ||
                    book.author.toLowerCase().contains(query) ||
                    book.description.toLowerCase().contains(query);
              }).toList();

        if (filteredBooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.menu_book_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'books_feature.empty.no_books_available'.tr()
                      : 'books_feature.empty.no_results'.tr(namedArgs: {'query': searchQuery}),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                // Show refresh button also on empty state
                const SizedBox(height: 16),
                 TextButton.icon(
                  onPressed: () => ref.invalidate(allBooksNotifierProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allBooksNotifierProvider);
            // ننتظر قليلاً للتأكد من اكتمال الـ rebuild وظهور حالة التحميل
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.65,
            ),
            itemCount: filteredBooks.length,
            itemBuilder: (context, index) {
              final book = filteredBooks[index];
              return GestureDetector(
                onTap: () => _showBookDialog(context, ref, book),
                child: _BookCard(
                  book: book,
                  searchQuery: searchQuery,
                  onTap: () => _showBookDialog(context, ref, book),
                ),
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }

  static void _showBookDialog(BuildContext context, WidgetRef ref, dynamic book) {
    // ... (rest of the dialog code) ...
    final theme = Theme.of(context);
    final distributorsAsync = ref.read(distributorsProvider);
    final owner = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == book.userId);
    final ownerName = owner?.displayName ?? book.userName ?? 'مستخدم';
    ref.read(allBooksNotifierProvider.notifier).incrementViews(book.id);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: book.imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserBooksScreen(
                              userId: book.userId,
                              userName: ownerName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                ownerName,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 8),
                        Text(
                          book.author,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      book.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatChip(
                          context: context,
                          icon: Icons.price_change,
                          label: 'books_feature.price'.tr(),
                          value: '${NumberFormatter.formatCompact(book.price)} ${'products.currency'.tr()}',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          context: context,
                          icon: Icons.visibility,
                          label: 'books_feature.views'.tr(),
                          value: NumberFormatter.formatCompact(book.views),
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BookDetailsScreen(book: book),
                                ),
                              );
                            },
                            label: Text('books_feature.book_details'.tr()),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openWhatsApp(context, book.phone);
                            },
                            icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                            label: Text(
                              'books_feature.contact'.tr(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('books_feature.whatsapp_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ===================================================================
// Expire Soon Tab - المنتجات منتهية الصلاحية
// ===================================================================
class ExpireSoonTab extends ConsumerWidget {
  const ExpireSoonTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expireDrugsAsync = ref.watch(expireDrugsProvider);
    final filters = ref.watch(searchFiltersProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);

    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return expireDrugsAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => TabErrorView(
        message: 'products.error_occurred'.tr(),
        onRetry: () => ref.invalidate(expireDrugsProvider),
      ),
      data: (items) {
        // ... (data processing logic remains same) ...
        var filteredItems = items.where((item) {
          final product = item.product;
          bool matchesSearch = true;
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            matchesSearch = product.name.toLowerCase().contains(query) ||
                (product.activePrinciple ?? '').toLowerCase().contains(query) ||
                (product.company ?? '').toLowerCase().contains(query);
          }
          bool matchesGov = true;
          if (filters.selectedGovernorate != null) {
            final distributor = distributorsMap[product.distributorUuid ?? product.distributorId];
            if (distributor != null) {
              final List<String> govList = List<String>.from(distributor.governorates ?? []);
              matchesGov = govList.contains(filters.selectedGovernorate);
            } else {
              matchesGov = false;
            }
          }
          return matchesSearch && matchesGov;
        }).toList();

        filteredItems.sort((a, b) {
          final prodA = a.product;
          final prodB = b.product;
          if (filters.isCheapest) {
            final priceA = prodA.price ?? double.infinity;
            final priceB = prodB.price ?? double.infinity;
            if (priceA != priceB) return priceA.compareTo(priceB);
          }
          final currentUser = currentUserAsync.asData?.value;
          if (currentUser != null && distributorsMap.isNotEmpty) {
            final distributorA = distributorsMap[prodA.distributorUuid ?? prodA.distributorId];
            final distributorB = distributorsMap[prodB.distributorUuid ?? prodB.distributorId];
            if (distributorA != null && distributorB != null) {
              final proximityA = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorA.governorates,
                distributorCenters: distributorA.centers,
              );
              final proximityB = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorB.governorates,
                distributorCenters: distributorB.centers,
              );
              if (proximityA != proximityB) return proximityB.compareTo(proximityA);
            }
          }
          return 0;
        });

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? Icons.inventory_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? 'products.empty.no_expire_soon'.tr()
                      : 'products.no_results'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                 TextButton.icon(
                  onPressed: () => ref.invalidate(expireDrugsProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(expireDrugsProvider);
            await ref.read(expireDrugsProvider.future);
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return ViewTrackingProductCard(
                product: item.product,
                searchQuery: searchQuery,
                productType: 'expire_soon',
                trackViewOnVisible: true, 
                expirationDate: item.expirationDate,
                onTap: () {
                  showProductDialog(
                    context,
                    item.product,
                    expirationDate: item.expirationDate,
                  );
                },
                overlayBadge: item.expirationDate != null
                    ? _buildExpirationBadge(
                        context,
                        item.expirationDate!,
                      )
                    : null,
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }

  Widget _buildExpirationBadge(BuildContext context, DateTime expirationDate) {
    final now = DateTime.now();
    final isExpired = expirationDate.isBefore(DateTime(now.year, now.month + 1));

    return Positioned(
      bottom: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isExpired ? Colors.red.shade700 : Colors.orange.shade700,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('MM/yyyy').format(expirationDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Surgical & Diagnostic Tab - الأدوات الجراحية
// ===================================================================
class SurgicalDiagnosticTab extends ConsumerWidget {
  const SurgicalDiagnosticTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(surgicalToolsHomeProvider);
    final filters = ref.watch(searchFiltersProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);

    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return toolsAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => TabErrorView(
        message: 'surgical_tools_feature.messages.generic_error'.tr(),
        onRetry: () => ref.invalidate(surgicalToolsHomeProvider),
      ),
      data: (tools) {
        // ... (data processing logic) ...
        var filteredTools = tools.where((tool) {
          bool matchesSearch = true;
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            matchesSearch = tool.name.toLowerCase().contains(query) ||
                (tool.company ?? '').toLowerCase().contains(query) ||
                (tool.description ?? '').toLowerCase().contains(query);
          }
          bool matchesGov = true;
          if (filters.selectedGovernorate != null) {
            final distributor = distributorsMap[tool.distributorUuid ?? tool.distributorId];
            if (distributor != null) {
              final List<String> govList = List<String>.from(distributor.governorates ?? []);
              matchesGov = govList.contains(filters.selectedGovernorate);
            } else {
              matchesGov = false;
            }
          }
          return matchesSearch && matchesGov;
        }).toList();

        filteredTools.sort((a, b) {
          if (filters.isCheapest) {
            final priceA = a.price ?? double.infinity;
            final priceB = b.price ?? double.infinity;
            if (priceA != priceB) return priceA.compareTo(priceB);
          }
          final currentUser = currentUserAsync.asData?.value;
          if (currentUser != null && distributorsMap.isNotEmpty) {
            final distributorA = distributorsMap[a.distributorUuid ?? a.distributorId];
            final distributorB = distributorsMap[b.distributorUuid ?? b.distributorId];
            if (distributorA != null && distributorB != null) {
              final proximityA = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorA.governorates,
                distributorCenters: distributorA.centers,
              );
              final proximityB = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorB.governorates,
                distributorCenters: distributorB.centers,
              );
              if (proximityA != proximityB) return proximityB.compareTo(proximityA);
            }
          }
          return 0;
        });

        if (filteredTools.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? Icons.medical_services_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? 'surgical_tools_feature.empty.no_tools'.tr()
                      : 'surgical_tools_feature.search.no_results'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                 TextButton.icon(
                  onPressed: () => ref.invalidate(surgicalToolsHomeProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(surgicalToolsHomeProvider);
            await ref.read(surgicalToolsHomeProvider.future);
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.65, 
            ),
            itemCount: filteredTools.length,
            itemBuilder: (context, index) {
              final tool = filteredTools[index];
              return ViewTrackingProductCard(
                product: tool,
                searchQuery: searchQuery,
                productType: 'surgical',
                trackViewOnVisible: true, 
                status: tool.activePrinciple,
                onTap: () {
                  showSurgicalToolDialog(context, tool);
                },
                statusBadge: tool.activePrinciple != null &&
                        tool.activePrinciple!.isNotEmpty
                    ? _buildStatusBadge(
                        context,
                        tool.activePrinciple!,
                      )
                    : null,
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color getBadgeColor() {
      switch (status) {
        case 'جديد':
          return Colors.green;
        case 'مستعمل':
          return Colors.orange;
        case 'كسر زيرو':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    IconData getBadgeIcon() {
      switch (status) {
        case 'جديد':
          return Icons.new_releases_rounded;
        case 'مستعمل':
          return Icons.history_rounded;
        case 'كسر زيرو':
          return Icons.star_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getBadgeColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getBadgeIcon(),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Offers Tab - العروض
// ===================================================================
class OffersTab extends ConsumerWidget {
  const OffersTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersHomeProvider);
    final filters = ref.watch(searchFiltersProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);

    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return offersAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => TabErrorView(
        message: 'offers.dialog.generic_error'.tr(),
        onRetry: () => ref.invalidate(offersHomeProvider),
      ),
      data: (offerItems) {
        // ... (data processing logic) ...
        var filteredOfferItems = offerItems.where((item) {
          final offer = item.product;
          bool matchesSearch = true;
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            matchesSearch = offer.name.toLowerCase().contains(query) ||
                (offer.activePrinciple ?? '').toLowerCase().contains(query) ||
                (offer.company ?? '').toLowerCase().contains(query);
          }
          bool matchesGov = true;
          if (filters.selectedGovernorate != null) {
            final distributor = distributorsMap[offer.distributorUuid ?? offer.distributorId];
            if (distributor != null) {
              final List<String> govList = List<String>.from(distributor.governorates ?? []);
              matchesGov = govList.contains(filters.selectedGovernorate);
            } else {
              matchesGov = false;
            }
          }
          return matchesSearch && matchesGov;
        }).toList();

        filteredOfferItems.sort((a, b) {
          final prodA = a.product;
          final prodB = b.product;
          if (filters.isCheapest) {
            final priceA = prodA.price ?? double.infinity;
            final priceB = prodB.price ?? double.infinity;
            if (priceA != priceB) return priceA.compareTo(priceB);
          }
          final currentUser = currentUserAsync.asData?.value;
          if (currentUser != null && distributorsMap.isNotEmpty) {
            final distributorA = distributorsMap[prodA.distributorUuid ?? prodA.distributorId];
            final distributorB = distributorsMap[prodB.distributorUuid ?? prodB.distributorId];
            if (distributorA != null && distributorB != null) {
              final proximityA = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorA.governorates,
                distributorCenters: distributorA.centers,
              );
              final proximityB = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorB.governorates,
                distributorCenters: distributorB.centers,
              );
              if (proximityA != proximityB) return proximityB.compareTo(proximityA);
            }
          }
          return 0;
        });

        if (filteredOfferItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? Icons.local_offer_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty && filters.selectedGovernorate == null
                      ? 'offers.tabs.no_offers'.tr()
                      : 'offers.tabs.no_results'.tr(namedArgs: {'query': searchQuery}),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
                 TextButton.icon(
                  onPressed: () => ref.invalidate(offersHomeProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(offersHomeProvider);
            await ref.read(offersHomeProvider.future);
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredOfferItems.length,
            itemBuilder: (context, index) {
              final item = filteredOfferItems[index];
              return ViewTrackingProductCard(
                product: item.product,
                searchQuery: searchQuery,
                productType: 'offers',
                trackViewOnVisible: true, 
                onTap: () {
                  showOfferProductDialog(
                    context,
                    item.product,
                    expirationDate: item.expirationDate,
                  );
                },
                overlayBadge: Positioned(
                  top: 6,
                  left: -40,
                  child: Transform.rotate(
                    angle: -0.785398, // -45 درجة
                    child: Container(
                      width: 120,
                      height: 25,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE53935), // أحمر غامق
                            Color(0xFFEF5350), // أحمر فاتح
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'offers.card.badge'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }
}

// ===================================================================
// Book Card Widget
// ===================================================================
class _BookCard extends StatelessWidget {
  final dynamic book;
  final String searchQuery;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: book.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.orange[100],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.orange[100],
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.orange,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            // Book Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${NumberFormatter.formatCompact(book.price)} LE',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Text(
                              NumberFormatter.formatCompact(book.views),
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ===================================================================
// Course Card Horizontal Widget (for home tab)
// ===================================================================
class _CourseCardHorizontal extends StatelessWidget {
  final dynamic course;
  final String searchQuery;
  final VoidCallback onTap;

  const _CourseCardHorizontal({
    required this.course,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Course Poster Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: course.imageUrl,
                  width: 120,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.blue[100],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.blue[100],
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Course Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Description
                    Text(
                      course.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Bottom Row: Price and Views
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${NumberFormatter.formatCompact(course.price)} LE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Views
                        Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormatter.formatCompact(course.views),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}