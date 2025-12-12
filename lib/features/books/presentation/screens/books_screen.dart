import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/books/presentation/screens/add_book_screen.dart';
import 'package:fieldawy_store/features/books/presentation/screens/edit_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class BooksScreen extends ConsumerWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(myBooksNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'books_feature.title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.iconTheme.color),
            onPressed: () {
              ref.invalidate(myBooksNotifierProvider);
            },
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (error, stack) => _buildErrorState(context, ref, error),
        data: (books) {
          if (books.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myBooksNotifierProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookCard(
                  book: book,
                  onDelete: () => _deleteBook(context, ref, book.id, book.name),
                  onEdit: () => _editBook(context, ref, book),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddBookScreen(),
            ),
          );
          ref.invalidate(myBooksNotifierProvider);
        },
        tooltip: 'books_feature.add_book_tooltip'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 100,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 24),
          Text(
            'books_feature.no_books'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'books_feature.add_first_book'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 80, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              'books_feature.error_connection'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(myBooksNotifierProvider),
              icon: const Icon(Icons.refresh),
              label: Text('books_feature.retry'.tr()),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _deleteBook(BuildContext context, WidgetRef ref, String bookId, String bookName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('books_feature.confirm_delete_title'.tr()),
        content: Text('books_feature.confirm_delete_msg'.tr(namedArgs: {'name': bookName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('books_feature.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('books_feature.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await ref.read(myBooksNotifierProvider.notifier).deleteBook(bookId);
        if (success) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('books_feature.delete_success'.tr()),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('books_feature.delete_failed'.tr()),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('books_feature.error_occurred'.tr(namedArgs: {'error': e.toString()})),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static Future<void> _editBook(BuildContext context, WidgetRef ref, dynamic book) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditBookScreen(book: book),
      ),
    );
    
    if (result == true) {
      // Refresh the list
      ref.invalidate(myBooksNotifierProvider);
    }
  }
}

class _BookCard extends StatelessWidget {
  final dynamic book;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BookCard({required this.book, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBookDetailsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // --- Book Image ---
              SizedBox(
                width: 100,
                height: 100,
                child: Hero(
                  tag: 'book_image_${book.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: book.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.menu_book,
                            color: colorScheme.primary, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // --- Book Info ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            book.author,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${book.price.toStringAsFixed(0)} ج.م',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 16, color: theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 4),
                            Text(
                              '${book.views}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // --- Actions Menu ---
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('books_feature.edit'.tr()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Text('books_feature.delete'.tr()),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookDetailsSheet(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: _BookDetailsContent(book: book),
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
          const SnackBar(
            content: Text('لا يمكن فتح WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// --- New Widget for the Bottom Sheet Content ---

class _BookDetailsContent extends StatelessWidget {
  final dynamic book;

  const _BookDetailsContent({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        Stack(
          children: [
            Hero(
              tag: 'book_image_${book.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: book.imageUrl,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
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
        // --- Content ---
        Padding(
          padding: const EdgeInsets.all(24.0),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              // --- Stats Section ---
              Row(
                children: [
                  _buildStatChip(
                    context: context,
                    icon: Icons.price_change,
                    label: 'السعر',
                    value: '${book.price.toStringAsFixed(0)} ج.م',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    context: context,
                    icon: Icons.visibility,
                    label: 'مشاهدات',
                    value: '${book.views}',
                    color: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // --- Action Button ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _BookCard._openWhatsApp(context, book.phone);
                  },
                  icon: const Icon(Icons.phone_in_talk_outlined,
                      color: Colors.white),
                  label: const Text(
                    'تواصل مع البائع',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
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
            Text(label,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
