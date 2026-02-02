import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/clinic_inventory_item.dart';

/// بطاقة عنصر الجرد
class InventoryItemCard extends StatelessWidget {
  final ClinicInventoryItem item;
  final VoidCallback? onTap;

  const InventoryItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // الصورة
            _buildImage(colorScheme),
            const SizedBox(width: 14),

            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم والشارات
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStockBadge(colorScheme),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // العبوة والشركة
                  Row(
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-icon.png',
                        width: 14,
                        height: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                        placeholder: (context, url) => Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.package,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (item.company != null) ...[
                        const SizedBox(width: 12),
                        CachedNetworkImage(
                          imageUrl:
                              'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Building-icon.png',
                          width: 14,
                          height: 14,
                          color: colorScheme.onSurface.withOpacity(0.5),
                          placeholder: (context, url) => Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.company!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // الكمية والصلاحية
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الكمية
                      Flexible(
                        child: _buildQuantityChip(theme, colorScheme, isArabic),
                      ),

                      // السعر
                      Text(
                        '${item.purchasePrice.toStringAsFixed(0)} ${isArabic ? 'ج' : 'EGP'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // السهم
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(ColorScheme colorScheme) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.contain,
                placeholder: (_, __) => _buildPlaceholder(colorScheme),
                errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
              ),
            )
          : _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: CachedNetworkImage(
        imageUrl:
            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Prescription-Bottle-Medical-icon.png',
        width: 32,
        height: 32,
        color: colorScheme.primary.withOpacity(0.5),
        placeholder: (_, __) => Icon(
          Icons.medication_outlined,
          color: colorScheme.primary.withOpacity(0.5),
          size: 32,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.medication_outlined,
          color: colorScheme.primary.withOpacity(0.5),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildStockBadge(ColorScheme colorScheme) {
    Color color;
    String iconUrl;
    IconData fallbackIcon;

    switch (item.stockStatus) {
      case StockStatus.adequate:
        return const SizedBox.shrink();
      case StockStatus.low:
        color = Colors.orange;
        iconUrl =
            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Arrow-Trend-Down-icon.png';
        fallbackIcon = Icons.trending_down_rounded;
        break;
      case StockStatus.critical:
        color = Colors.red;
        iconUrl =
            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Triangle-Exclamation-icon.png';
        fallbackIcon = Icons.warning_amber_rounded;
        break;
      case StockStatus.outOfStock:
        color = Colors.red.shade700;
        iconUrl =
            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Ban-icon.png';
        fallbackIcon = Icons.remove_shopping_cart_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CachedNetworkImage(
        imageUrl: iconUrl,
        width: 16,
        height: 16,
        color: color,
        placeholder: (context, url) => Icon(
          fallbackIcon,
          color: color,
          size: 16,
        ),
        errorWidget: (context, url, error) => Icon(
          fallbackIcon,
          color: color,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildQuantityChip(
      ThemeData theme, ColorScheme colorScheme, bool isArabic) {
    final hasPartial = item.partialQuantity > 0;

    // ترجمة نوع العبوة
    String packageLabel = item.packageType;
    if (isArabic) {
      switch (item.packageType) {
        case 'box':
          packageLabel = 'علبة';
          break;
        case 'bottle':
          packageLabel = 'زجاجة';
          break;
        case 'vial':
          packageLabel = 'فيال';
          break;
        case 'ampoule':
          packageLabel = 'أمبول';
          break;
        case 'tube':
          packageLabel = 'أنبوب';
          break;
        case 'strip':
          packageLabel = 'شريط';
          break;
        case 'sachet':
          packageLabel = 'كيس';
          break;
        case 'can':
          packageLabel = 'علبة';
          break;
        case 'jar':
          packageLabel = 'برطمان';
          break;
        case 'bag':
          packageLabel = 'كيس';
          break;
      }
    } else {
      // English defaults (capitalized)
      switch (item.packageType) {
        case 'box':
          packageLabel = 'Box';
          break;
        case 'bottle':
          packageLabel = 'Bottle';
          break;
        case 'vial':
          packageLabel = 'Vial';
          break;
        case 'ampoule':
          packageLabel = 'Ampoule';
          break;
        case 'tube':
          packageLabel = 'Tube';
          break;
        case 'strip':
          packageLabel = 'Strip';
          break;
        case 'sachet':
          packageLabel = 'Sachet';
          break;
        case 'can':
          packageLabel = 'Can';
          break;
        case 'jar':
          packageLabel = 'Jar';
          break;
        case 'bag':
          packageLabel = 'Bag';
          break;
      }
    }

    // بناء مكونات النص باستخدام Text.rich لتجنب مشاكل Layout
    final List<InlineSpan> spans = [];
    final style = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    if (item.quantity > 0) {
      spans.add(TextSpan(text: '${item.quantity} $packageLabel', style: style));
    }

    if (item.quantity > 0 && hasPartial) {
      spans.add(TextSpan(text: ' + ', style: style));
    }

    if (hasPartial) {
      // إجبار اتجاه النص لليسار لليمين للأرقام والوحدات الإنجليزية/المختلطة
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Text(
            '${item.partialQuantity.toStringAsFixed(0)} ${item.translatedUnitType}',
            style: style,
          ),
        ),
      ));
    } else if (item.quantity <= 0 && !hasPartial) {
      spans.add(TextSpan(text: isArabic ? 'نفذ' : 'Out', style: style));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
