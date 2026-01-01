import 'dart:ui' as ui;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/orders/application/orders_provider.dart';
import 'package:fieldawy_store/features/products/application/favorites_provider.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductDetailsDialog extends ConsumerWidget {
  final ProductModel product;
  final String distributorName;
  final String distributorId;

  const ProductDetailsDialog({
    super.key,
    required this.product,
    required this.distributorName,
    required this.distributorId,
  });

  static Future<dynamic> show(BuildContext context, ProductModel product, String distributorName, String distributorId) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: ProductDetailsDialog(
              product: product,
              distributorName: distributorName,
              distributorId: distributorId,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation1,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: animation1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // جلب أحدث بيانات الموزعين لضمان ظهور الاسم المحدث
    final distributorsAsync = ref.watch(distributorsProvider);
    final latestDistributor = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == distributorId);
    final displayNameToUse = latestDistributor?.displayName ?? distributorName;

    // دالة لتصحيح ترتيب نص العبوة للغة العربية
    String formatPackageText(String package) {
      final currentLocale = Localizations.localeOf(context).languageCode;

      if (currentLocale == 'ar' &&
          package.toLowerCase().contains(' ml') &&
          package.toLowerCase().contains('vial')) {
        final parts = package.split(' ');
        if (parts.length >= 3) {
          final number = parts.firstWhere(
              (part) => RegExp(r'^\d+').hasMatch(part),
              orElse: () => '');
          final unit = parts.firstWhere(
              (part) => part.toLowerCase().contains(' ml'),
              orElse: () => '');
          final container = parts.firstWhere(
              (part) => part.toLowerCase().contains('vial'),
              orElse: () => '');

          if (number.isNotEmpty && unit.isNotEmpty && container.isNotEmpty) {
            return '$number$unit $container';
          }
        }
      }
      return package;
    }

    final backgroundGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E1E2E), Color(0xFF2A2A3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF8FDFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final containerColor = isDark ? Colors.grey.shade800.withAlpha(128) : Colors.white.withAlpha(204);
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
    final priceColor = isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
    final favoriteColor = isDark ? Colors.redAccent.shade100 : Colors.red.shade400;
    final packageBgColor = isDark ? const Color.fromARGB(255, 239, 241, 251).withAlpha(26) : Colors.blue.shade50.withAlpha(204);
    final packageBorderColor = isDark ? Colors.grey.shade600 : Colors.blue.shade200;
    final imageBgColor = isDark ? const Color.fromARGB(255, 21, 15, 15).withAlpha(77) : Colors.white.withAlpha(179);

    final order = ref.watch(orderProvider);
    final orderItemInCart = order.firstWhereOrNull((item) =>
        item.product.id == product.id &&
        item.product.distributorId == product.distributorId &&
        item.product.selectedPackage == product.selectedPackage);
    final isProductInCart = orderItemInCart != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isSmallScreen ? size.width * 0.95 : 400,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          gradient: backgroundGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(77) : Colors.black.withAlpha(26),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.grey.shade600.withAlpha(77) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // === Header ===
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: containerColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.close, color: iconColor),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () => DistributorDetailsSheet.show(context, distributorId),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withAlpha(77),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        displayNameToUse,
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        if (product.company != null && product.company!.isNotEmpty)
                          Text(
                            product.company!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(179),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                        const SizedBox(height: 8),

                        Text(
                          product.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 6),

                        if (product.activePrinciple != null && product.activePrinciple!.isNotEmpty)
                          Text(
                            product.activePrinciple!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(
                                '${NumberFormatter.formatCompact(product.price ?? 0)} ${'EGP'.tr()}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: priceColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Consumer(
                              builder: (context, ref, child) {
                                final favoritesMap = ref.watch(favoritesProvider);
                                final isFavorite = favoritesMap.containsKey(
                                    '${product.id}_${product.distributorId}_${product.selectedPackage}');
                                return Container(
                                  decoration: BoxDecoration(
                                    color: containerColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? Colors.red : favoriteColor,
                                    ),
                                    onPressed: () {
                                      ref.read(favoritesProvider.notifier).toggleFavorite(product);
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          elevation: 0,
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.transparent,
                                          content: AwesomeSnackbarContent(
                                            title: isFavorite ? 'تم الحذف' : 'نجاح',
                                            message: isFavorite
                                                ? 'تمت إزالة ${product.name} من المفضلة'
                                                : 'تمت إضافة ${product.name} للمفضلة',
                                            contentType: isFavorite
                                                ? ContentType.failure
                                                : ContentType.success,
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: imageBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(child: ImageLoadingIndicator(size: 50)),
                              errorWidget: (context, url, error) => Icon(
                                Icons.broken_image_outlined,
                                size: 60,
                                color: theme.colorScheme.onSurface.withAlpha(102),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'distributors_feature.products_screen.description'.tr(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'distributors_feature.products_screen.active_principle'.tr(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: product.activePrinciple ?? 'distributors_feature.products_screen.undefined'.tr(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (product.selectedPackage != null && product.selectedPackage!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: packageBgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: packageBorderColor,
                                  width: 1,
                                ),
                              ),
                              child: Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  formatPackageText(product.selectedPackage!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                        const SizedBox(height: 30),
                        
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primaryContainer.withAlpha(77),
                                  theme.colorScheme.secondaryContainer.withAlpha(51),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.primary.withAlpha(51),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                   'distributors_feature.products_screen.vet_eye_note'.tr(),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isProductInCart) {
                        ref.read(orderProvider.notifier).removeProduct(orderItemInCart);
                        Navigator.pop(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(isAr ? 'تم الحذف من السلة' : 'Removed from cart'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } else {
                        ref.read(orderProvider.notifier).addProduct(product);
                        Navigator.pop(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(isAr ? 'تمت الإضافة للسلة' : 'Added to cart'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DistributorProductsScreen(
                              distributorId: distributorId,
                              distributorName: displayNameToUse,
                              initialSearchQuery: product.name,
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isProductInCart ? Icons.check : Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      isProductInCart
                          ? 'distributors_feature.products_screen.remove_from_cart'.tr()
                          : 'distributors_feature.products_screen.add_to_cart'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isProductInCart ? Colors.green : theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
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
}