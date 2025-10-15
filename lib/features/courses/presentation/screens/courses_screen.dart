import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/add_course_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/edit_course_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCoursesNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'كورساتي',
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
              ref.invalidate(myCoursesNotifierProvider);
            },
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (error, stack) => _buildErrorState(context, ref, error),
        data: (courses) {
          if (courses.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myCoursesNotifierProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return _CourseCard(
                  course: course,
                  onDelete: () =>
                      _deleteCourse(context, ref, course.id, course.title),
                  onEdit: () => _editCourse(context, ref, course),
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
              builder: (context) => const AddCourseScreen(),
            ),
          );
          ref.invalidate(myCoursesNotifierProvider);
        },
        tooltip: 'إضافة كورس',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Helper Methods (Logic untouched, only UI improved) ---

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 100,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد كورسات بعد',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر + في الأسفل لإضافة أول كورس لك',
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
              'حدث خطأ في الاتصال',
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
              onPressed: () => ref.invalidate(myCoursesNotifierProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
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

  static Future<void> _deleteCourse(BuildContext context, WidgetRef ref,
      String courseId, String courseTitle) async {
    // This logic remains the same
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف كورس "$courseTitle"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await ref
            .read(myCoursesNotifierProvider.notifier)
            .deleteCourse(courseId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'تم حذف الكورس بنجاح' : 'فشل حذف الكورس'),
              backgroundColor: success ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  static Future<void> _editCourse(
      BuildContext context, WidgetRef ref, dynamic course) async {
    // This logic remains the same
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditCourseScreen(course: course),
      ),
    );
    if (result == true) {
      ref.invalidate(myCoursesNotifierProvider);
    }
  }

  static Future<void> _openWhatsApp(BuildContext context, String phone) async {
    // This logic remains the same
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

// --- New and Improved Course Card Widget for List View ---

class _CourseCard extends StatelessWidget {
  final dynamic course;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CourseCard(
      {required this.course, required this.onDelete, required this.onEdit});

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
        onTap: () => _showCourseDetailsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // --- Course Image ---
              SizedBox(
                width: 100,
                height: 100,
                child: Hero(
                  tag: 'course_image_${course.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: course.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.school,
                            color: colorScheme.primary, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // --- Course Info ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      course.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${course.price.toStringAsFixed(0)} ج.م',
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
                              '${course.views}',
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
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      SizedBox(width: 8),
                      Text('حذف'),
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

  void _showCourseDetailsSheet(BuildContext context) {
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
          child: _CourseDetailsContent(course: course),
        ),
      ),
    );
  }
}

// --- New Widget for the Bottom Sheet Content (Remains the same) ---

class _CourseDetailsContent extends StatelessWidget {
  final dynamic course;

  const _CourseDetailsContent({required this.course});

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
              tag: 'course_image_${course.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: course.imageUrl,
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
                course.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                course.description,
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
                    value: '${course.price.toStringAsFixed(0)} ج.م',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    context: context,
                    icon: Icons.visibility,
                    label: 'مشاهدات',
                    value: '${course.views}',
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
                    CoursesScreen._openWhatsApp(context, course.phone);
                  },
                  icon: const Icon(Icons.phone_in_talk_outlined,
                      color: Colors.white),
                  label: const Text(
                    'تواصل مع مقدم الكورس',
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
