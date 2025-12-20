import 'package:fieldawy_store/features/products/presentation/screens/tools_catalog_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/edit_surgical_tool_screen.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

class SurgicalToolsScreen extends ConsumerStatefulWidget {
  const SurgicalToolsScreen({super.key});

  @override
  ConsumerState<SurgicalToolsScreen> createState() => _SurgicalToolsScreenState();
}

class _SurgicalToolsScreenState extends ConsumerState<SurgicalToolsScreen> {
  bool _isLoading = false;

  Future<void> _deleteTool(
      BuildContext context, String id, String toolName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'surgical_tools_feature.dialogs.delete_confirm_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'surgical_tools_feature.dialogs.delete_confirm_message'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toolName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'surgical_tools_feature.dialogs.delete_warning'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('surgical_tools_feature.actions.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_rounded, size: 20),
                const SizedBox(width: 8),
                Text('surgical_tools_feature.actions.delete'.tr()),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      final success = await ref
          .read(productRepositoryProvider)
          .deleteDistributorSurgicalTool(id);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success ? 'surgical_tools_feature.messages.delete_success'.tr() : 'surgical_tools_feature.messages.delete_error'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (success) {
          // تحديث القائمة
          setState(() {});
        }
      }
    }
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'surgical_tools_feature.actions.add_tool'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.list_alt,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text('surgical_tools_feature.actions.select_from_catalog'.tr()),
                  subtitle: Text('surgical_tools_feature.actions.select_from_catalog_subtitle'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ToolsCatalogScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.12),
                    child: Icon(Icons.photo_library_outlined,
                        color: Colors.orange),
                  ),
                  title: Text('surgical_tools_feature.actions.select_from_gallery'.tr()),
                  subtitle: Text('surgical_tools_feature.actions.select_from_gallery_subtitle'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddProductOcrScreen(
                          showExpirationDate: false,
                          isFromOfferScreen: false,
                          isFromSurgicalTools: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshTools() async {
    setState(() => _isLoading = true);
    // لا حاجة لـ invalidate هنا لأننا نستخدم FutureBuilder يستدعي الدالة مباشرة
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authServiceProvider).currentUser?.id;
    final theme = Theme.of(context);
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('surgical_tools_feature.title'.tr()),
        ),
        body: Center(
          child: Text('surgical_tools_feature.messages.login_required'.tr()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text('surgical_tools_feature.my_tools_title'.tr()),
          ],
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text(
          'surgical_tools_feature.actions.add_tool_short'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        elevation: 4,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTools,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ref.read(productRepositoryProvider).getMySurgicalTools(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'surgical_tools_feature.messages.loading_tools'.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorState(
                error: snapshot.error.toString(),
                onRetry: _refreshTools,
              );
            }

            final tools = snapshot.data ?? [];

            if (tools.isEmpty) {
              return _EmptyState(onAddPressed: () => _showAddDialog(context));
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: _StatsCard(toolsCount: tools.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = tools[index];
                        final surgicalTool =
                            tool['surgical_tools'] as Map<String, dynamic>?;

                        final id = tool['id'] ?? '';
                        final toolName =
                            surgicalTool?['tool_name'] ?? 'Unknown';
                        final company = surgicalTool?['company'];
                        final imageUrl = surgicalTool?['image_url'];
                        final description = tool['description'] ?? '';
                        final price =
                            (tool['price'] as num?)?.toDouble() ?? 0.0;
                        final status = tool['status'] ?? 'جديد';

                        // Translate status for display
                        String displayStatus = status;
                        if (status == 'جديد') displayStatus = 'surgical_tools_feature.status.new'.tr();
                        else if (status == 'مستعمل') displayStatus = 'surgical_tools_feature.status.used'.tr();
                        else if (status == 'كسر زيرو') displayStatus = 'surgical_tools_feature.status.like_new'.tr();

                        return _ModernToolCard(
                          id: id,
                          toolName: toolName,
                          company: company,
                          imageUrl: imageUrl,
                          description: description,
                          price: price,
                          status: status,
                          displayStatus: displayStatus,
                          index: index,
                          onDelete: () => _deleteTool(context, id, toolName),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditSurgicalToolScreen(
                                  id: id,
                                  toolName: toolName,
                                  company: company,
                                  imageUrl: imageUrl,
                                  initialDescription: description,
                                  initialPrice: price,
                                  initialStatus: status,
                                ),
                              ),
                            );
                            // إذا تم التحديث بنجاح، نعيد تحميل القائمة
                            if (result == true) {
                              setState(() {});
                            }
                          },
                        );
                      },
                      childCount: tools.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===================================================================
// _StatsCard - بطاقة الإحصائيات
// ===================================================================
class _StatsCard extends StatelessWidget {
  final int toolsCount;

  const _StatsCard({required this.toolsCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.medical_services_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'surgical_tools_feature.stats.available_tools'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$toolsCount',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// _ModernToolCard - بطاقة الأداة المحسنة
// ===================================================================
class _ModernToolCard extends StatelessWidget {
  final String id;
  final String toolName;
  final String? company;
  final String? imageUrl;
  final String description;
  final double price;
  final String status;
  final String displayStatus;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ModernToolCard({
    required this.id,
    required this.toolName,
    required this.company,
    required this.imageUrl,
    required this.description,
    required this.price,
    required this.status,
    required this.displayStatus,
    required this.index,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.cardColor,
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.15),
            ),
            boxShadow: theme.brightness == Brightness.light
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // صورة الأداة
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceVariant,
                                child: const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.medical_services_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 32,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.medical_services_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 32,
                              ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // تفاصيل الأداة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toolName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Company
                        if (company != null && company!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 12,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  company!,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayStatus,
                                style: textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Price chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sell_outlined,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${NumberFormat('#,##0', 'en_US').format(price)} EGP',
                                style: textTheme.labelMedium?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // الوصف في حدود أنيقة
                        if (description.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              description,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                height: 1.4,
                              ),
                              maxLines: 9,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // زر الحذف في الزاوية العلوية اليمني
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 249, 248, 248),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      color: const Color.fromARGB(255, 226, 14, 14),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
    );
  }

  Color _getStatusColor(String status) {
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

  IconData _getStatusIcon(String status) {
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
}

// ===================================================================
// _EmptyState - حالة فارغة محسنة
// ===================================================================
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.primaryContainer.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'surgical_tools_feature.empty.no_tools'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'surgical_tools_feature.empty.start_adding'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'surgical_tools_feature.actions.add_tool'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
// _ErrorState - حالة الخطأ المحسنة
// ===================================================================
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'surgical_tools_feature.messages.load_error'.tr(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'surgical_tools_feature.actions.retry'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                side: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
