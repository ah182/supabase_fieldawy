// ignore_for_file: unused_import

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/products/domain/product_model.dart';
import 'dart:ui' as ui;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class CustomProductDialog extends StatelessWidget {
  const CustomProductDialog({super.key, required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان حسب الثيم
    final backgroundColor =
        isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);
    final containerColor = isDark
        ? Colors.grey.shade800.withOpacity(0.5)
        : Colors.white.withOpacity(0.8);
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
    final packageBgColor = isDark
        ? const Color.fromARGB(255, 216, 222, 249).withOpacity(0.1)
        : Colors.blue.shade50.withOpacity(0.8);
    final packageBorderColor = isDark
        ? const Color.fromARGB(255, 102, 126, 162)
        : Colors.blue.shade200;
    final imageBgColor = isDark
        ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
        : Colors.white.withOpacity(0.7);

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark
                ? const Color.fromARGB(255, 53, 47, 47).withOpacity(0.3)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Header مع زر الرجوع ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: containerColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: iconColor),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        // مساحة فارغة بدلاً من badge اسم الموزع
                        const SizedBox(width: 48),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // === اسم الشركة ===
                    if (product.company != null && product.company!.isNotEmpty)
                      Text(
                        product.company!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // === اسم المنتج ===
                    Text(
                      product.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // === المادة الفعالة ===
                    if (product.activePrinciple != null &&
                        product.activePrinciple!.isNotEmpty)
                      Text(
                        product.activePrinciple!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // === صورة المنتج ===
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
                          placeholder: (context, url) => const Center(
                              child: ImageLoadingIndicator(
                            size: 50,
                          )),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image_outlined,
                            size: 60,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // === وصف المنتج ===
                    Text(
                      'Active principle',
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
                            text: '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: product.activePrinciple ?? 'غير محدد',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // === العبوة ===
                    if (product.selectedPackage != null &&
                        product.selectedPackage!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: packageBgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: packageBorderColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: isDark
                                    ? const Color.fromARGB(255, 6, 149, 245)
                                    : const Color.fromARGB(255, 4, 90, 160),
                              ),
                              const SizedBox(width: 8),
                              Directionality(
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
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // === رسالة التطبيق - مُكبرة ===
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer
                                  .withOpacity(0.3),
                              theme.colorScheme.secondaryContainer
                                  .withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                 'لمزيد من المعلومات الطبية حول المنتج يرجي زيارة تطبيق Vet Eye ',
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
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
