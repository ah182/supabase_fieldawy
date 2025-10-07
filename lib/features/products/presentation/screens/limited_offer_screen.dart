import 'package:easy_localization/easy_localization.dart' hide NumberFormat;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/offer_detail_screen.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';



// ===================================================================
// LimitedOfferScreen - شاشة العروض المحدودة المحسنة
// ===================================================================
class LimitedOfferScreen extends ConsumerWidget {
  const LimitedOfferScreen({super.key});

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
                    'addProduct.limitedOffer.title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    child: Icon(Icons.inventory_2_outlined,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Add from Catalog'),
                  subtitle: const Text('اختر من الكتالوج'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const AddFromCatalogScreen(
                        showExpirationDate: true,
                        isFromOfferScreen: true,
                      ),
                    ));
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
                  title: const Text('Add from Gallery'),
                  subtitle: const Text('إضافة من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const AddProductOcrScreen(
                        showExpirationDate: true,
                        isFromOfferScreen: true,
                      ),
                    ));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(myOffersProvider);
    final theme = Theme.of(context);

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
              child: Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('العروض المحدودة'),
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
        label: const Text(
          'إضافة عرض',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        elevation: 4,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return _EmptyState(onAddPressed: () => _showAddDialog(context));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myOffersProvider);
            },
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: _StatsCard(offersCount: offers.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = offers[index];
                        final offer = item['offer'] as Map<String, dynamic>;
                        final product = item['product'] as Map<String, dynamic>;

                        return _ModernOfferCard(
                          offer: offer,
                          product: product,
                          index: index,
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => OfferDetailScreen(
                                  offerId: offer['id'].toString(),
                                  productName: product['name'] ?? '',
                                  price: (offer['price'] as num).toDouble(),
                                  expirationDate:
                                      DateTime.parse(offer['expiration_date']),
                                  currentDescription: offer['description'],
                                ),
                              ),
                            );
                            // إعادة تحميل العروض بعد التحديث
                            if (result == true && context.mounted) {
                              ref.invalidate(myOffersProvider);
                            }
                          },
                        );
                      },
                      childCount: offers.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل العروض...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => _ErrorState(
          error: error.toString(),
          onRetry: () => ref.invalidate(myOffersProvider),
        ),
      ),
    );
  }
}



// ===================================================================
// _StatsCard - بطاقة الإحصائيات
// ===================================================================
class _StatsCard extends StatelessWidget {
  final int offersCount;

  const _StatsCard({required this.offersCount});

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
            Icons.local_offer_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Active Offers :',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$offersCount',
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
// _ModernOfferCard - بطاقة العرض المحسنة
// ===================================================================
class _ModernOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Map<String, dynamic> product;
  final int index;
  final VoidCallback onTap;

  const _ModernOfferCard({
    required this.offer,
    required this.product,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    final now = DateTime.now();
    final expirationDate = DateTime.parse(offer['expiration_date']);
    final createdAt = offer['created_at'] != null 
        ? DateTime.parse(offer['created_at'])
        : now;
    
    // حساب الأيام المتبقية قبل حذف العرض (7 أيام من تاريخ الإنشاء)
    final deletionDate = createdAt.add(const Duration(days: 7));
    final daysUntilDeletion = deletionDate.difference(now).inDays;
    final isOfferExpired = daysUntilDeletion < 0;

    // تحديد اللون والحالة بناءً على الأيام المتبقية للعرض
    Color statusColor;
    String statusText;
    Color statusBgColor;

    if (isOfferExpired || daysUntilDeletion == 0) {
      statusColor = colorScheme.error;
      statusText = daysUntilDeletion == 0 ? 'ينتهي اليوم' : 'منتهي';
      statusBgColor = colorScheme.errorContainer;
    } else if (daysUntilDeletion <= 2) {
      statusColor = Colors.red.shade700;
      statusText = 'ينتهي قريباً جداً';
      statusBgColor = Colors.red.shade100;
    } else if (daysUntilDeletion <= 4) {
      statusColor = Colors.orange.shade700;
      statusText = 'ينتهي قريباً';
      statusBgColor = Colors.orange.shade100;
    } else {
      statusColor = Colors.green.shade600;
      statusText = 'ساري';
      statusBgColor = Colors.green.shade100;
    }

    final priceLabel = '${NumberFormat('#,##0.00', 'en_US').format((offer['price'] as num).toDouble())} EGP';
    final expirationLabel =
        '${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}';

    Widget buildInfoChip({
      required IconData icon,
      required String label,
      required Color background,
      required Color foreground,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة صغيرة على الجانب
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CachedNetworkImage(
                            imageUrl: product['imageUrl'] ?? '',
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
                                Icons.medication_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // المحتوى
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Unknown Product',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Package و Company
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (product['company'] != null &&
                                    product['company'].toString().isNotEmpty)
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
                                          product['company'],
                                          style: textTheme.labelMedium?.copyWith(
                                            color: colorScheme.onTertiaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (product['package'] != null &&
                                    product['package'].toString().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_rounded,
                                          size: 12,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          product['package'],
                                          style: textTheme.labelMedium?.copyWith(
                                            color: colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Chips للمعلومات
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                buildInfoChip(
                                  icon: Icons.sell_outlined,
                                  label: priceLabel,
                                  background: Colors.green.shade100,
                                  foreground: Colors.green.shade700,
                                ),
                                buildInfoChip(
                                  icon: Icons.schedule_outlined,
                                  label: expirationLabel,
                                  background: colorScheme.primaryContainer,
                                  foreground: colorScheme.onPrimaryContainer,
                                ),
                              ],
                            ),
                            // الوصف في حدود أنيقة
                            if (offer['description'] != null &&
                                offer['description'].toString().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  offer['description'],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // عرض المدة المتبقية مع زر الحذف
                  Row(
                    children: [
                      // Status badge بناءً على الأيام المتبقية للعرض
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOfferExpired
                                  ? Icons.cancel_rounded
                                  : daysUntilDeletion <= 2
                                      ? Icons.warning_rounded
                                      : daysUntilDeletion <= 4
                                          ? Icons.access_time_rounded
                                          : Icons.check_circle_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // زر الحذف
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        iconSize: 18,
                        color: Colors.red[600],
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: colorScheme.error,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('حذف العرض'),
                                ],
                              ),
                              content: const Text(
                                'هل أنت متأكد من حذف هذا العرض؟\nلن تتمكن من التراجع عن هذا الإجراء.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.error,
                                    foregroundColor: colorScheme.onError,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              final ref = ProviderScope.containerOf(context).read(productRepositoryProvider);
                              await ref.deleteOffer(offer['id'].toString());
                              
                              if (context.mounted) {
                                ProviderScope.containerOf(context).invalidate(myOffersProvider);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorScheme.errorContainer,
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'تم حذف العرض بنجاح',
                                            style: TextStyle(
                                              color: colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorScheme.errorContainer,
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.error_rounded,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'فشل حذف العرض',
                                            style: TextStyle(
                                              color: colorScheme.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // عرض المدة المتبقية للعرض قبل الحذف
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: daysUntilDeletion <= 2
                              ? Colors.red.shade50
                              : daysUntilDeletion <= 4
                                  ? Colors.orange.shade50
                                  : colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: daysUntilDeletion <= 2
                                ? Colors.red.shade200
                                : daysUntilDeletion <= 4
                                    ? Colors.orange.shade200
                                    : colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOfferExpired
                                  ? Icons.delete_sweep_outlined
                                  : Icons.timer_outlined,
                              size: 14,
                              color: daysUntilDeletion <= 2
                                  ? Colors.red.shade700
                                  : daysUntilDeletion <= 4
                                      ? Colors.orange.shade700
                                      : colorScheme.onSurface.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOfferExpired
                                  ? 'تم الحذف'
                                  : daysUntilDeletion == 0
                                      ? 'يُحذف اليوم'
                                      : 'باقي ${daysUntilDeletion > 0 ? daysUntilDeletion : 0} ${daysUntilDeletion == 1 ? 'يوم' : 'أيام'}',
                              style: textTheme.labelSmall?.copyWith(
                                color: daysUntilDeletion <= 2
                                    ? Colors.red.shade700
                                    : daysUntilDeletion <= 4
                                        ? Colors.orange.shade700
                                        : colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                Icons.local_offer_outlined,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'لا توجد عروض متاحة حالياً',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'أضف عرضك الأول لجذب المزيد من العملاء\nوزيادة مبيعاتك',
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
              label: const Text(
                'إضافة عرض جديد',
                style: TextStyle(
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
              'حدث خطأ في تحميل العروض',
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
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(
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
