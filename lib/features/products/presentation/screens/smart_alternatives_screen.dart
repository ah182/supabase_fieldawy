import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/product_dialogs.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class SmartAlternativesScreen extends ConsumerWidget {
  const SmartAlternativesScreen({
    super.key,
    required this.originalProduct,
    required this.alternatives,
  });

  final ProductModel originalProduct;
  final List<ProductModel> alternatives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar with Context
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: theme.colorScheme.onSurface),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                isAr ? 'بدائل ذكية' : 'Smart Alternatives',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.05),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Subtitle and Sorting Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 16, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'مرتبة حسب الأوفر والأقرب لك'
                          : 'Sorted by best value & location',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alternatives Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.63,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final alt = alternatives[index];
                  return _AlternativeProductCard(
                    alt: alt,
                    index: index,
                    originalProduct: originalProduct,
                    distributorsAsync: distributorsAsync,
                    isAr: isAr,
                  );
                },
                childCount: alternatives.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeProductCard extends StatelessWidget {
  const _AlternativeProductCard({
    required this.alt,
    required this.index,
    required this.originalProduct,
    required this.distributorsAsync,
    required this.isAr,
  });

  final ProductModel alt;
  final int index;
  final ProductModel originalProduct;
  final AsyncValue distributorsAsync;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double originalPrice = originalProduct.price ?? 0.0;
    final double altPrice = alt.price ?? 0.0;
    final double savings =
        originalPrice > altPrice ? originalPrice - altPrice : 0.0;

// منطق الحصول على اسم الموزع المحدث بطريقة آمنة تماماً
    final currentDistributorName = distributorsAsync.maybeWhen(
      data: (distributors) {
        // 1. نبحث عن العناصر المطابقة أولاً
        final matches = distributors.where((d) => d.id == alt.distributorUuid);

        // 2. إذا وجدنا نتيجة نأخذ الأولى، وإلا نعتبرها null
        final dist = matches.isEmpty ? null : matches.first;

        return dist?.displayName ?? alt.distributorId;
      },
      orElse: () => alt.distributorId,
    );

    // منطق الألوان للبوردر
    Color borderColor = Colors.transparent;
    double borderWidth = 0.0;
    
    if (altPrice < originalPrice && originalPrice > 0) {
      borderColor = Colors.green.withOpacity(0.5);
      borderWidth = 1.5;
    } else if (altPrice > originalPrice && originalPrice > 0) {
      borderColor = Colors.red.withOpacity(0.3);
      borderWidth = 1.0;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        showProductDialog(context, alt);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: borderWidth > 0 
              ? Border.all(color: borderColor, width: borderWidth)
              : Border.all(color: theme.dividerColor.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Modern Badging
            Expanded(
              flex: 12,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Hero(
                      tag: 'alt_screen_${alt.id}_$index',
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CachedNetworkImage(
                          imageUrl: alt.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                              Icons.medication_rounded,
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              size: 40),
                        ),
                      ),
                    ),
                  ),

                  // Savings Badge
                  if (savings > 0)
                    Positioned(
                      top: 16,
                      left: isAr ? null : 16,
                      right: isAr ? 16 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Text(
                          '${isAr ? 'وفر' : 'Save'} ${NumberFormatter.formatCompact(savings)} ${isAr ? 'ج.م' : 'LE'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Details
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الاسم
                    Text(
                      alt.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // 2. حجم العبوة
                    if (alt.selectedPackage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alt.selectedPackage!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 4), // مسافة صغيرة جداً كما طلبت
                    
                    // 3. اسم الموزع
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            currentDistributorName ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4), // مسافة صغيرة جداً بين الموزع والسعر
                    
                    // 4. السعر
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          NumberFormatter.formatCompact(altPrice),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: savings > 0
                                ? Colors.green.shade700
                                : (altPrice > originalPrice ? Colors.red.shade700 : theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isAr ? 'ج.م' : 'LE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
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
