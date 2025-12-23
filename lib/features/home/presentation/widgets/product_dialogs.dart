// ignore_for_file: unused_import

import 'package:fieldawy_store/features/books/presentation/screens/book_details_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/course_details_screen.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:fieldawy_store/widgets/user_details_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/surgical_tools/presentation/screens/surgical_tool_details_screen.dart';
import 'package:fieldawy_store/features/surgical_tools/presentation/screens/distributor_surgical_tools_screen.dart';
import 'package:fieldawy_store/features/books/presentation/screens/user_books_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/user_courses_screen.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';

import 'package:collection/collection.dart';
import 'dart:ui' as ui;
// ignore: unnecessary_import
import 'package:intl/intl.dart';

/// Dialog لعرض تفاصيل منتج عادي
Future<void> showProductDialog(
  BuildContext context,
  ProductModel product, {
  DateTime? expirationDate,
}) {
  return showDialog(
    context: context,
    builder: (context) => _ProductDialog(
      product: product,
      expirationDate: expirationDate,
    ),
  );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.product,
    this.expirationDate,
  });

  final ProductModel product;
  final DateTime? expirationDate;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  String? _phoneNumber;
  String? _role;
  bool _isLoadingPhone = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    setState(() => _isLoadingPhone = true);
    try {
      final supabase = Supabase.instance.client;
      
      if (widget.product.distributorUuid != null && widget.product.distributorUuid!.isNotEmpty) {
        final response = await NetworkGuard.execute(() async {
          return await supabase
              .from('users')
              .select('whatsapp_number, role')
              .eq('id', widget.product.distributorUuid!)
              .maybeSingle();
        });

        if (response != null) {
          setState(() {
            if (response['whatsapp_number'] != null) {
              _phoneNumber = response['whatsapp_number'].toString();
            }
            _role = response['role']?.toString();
          });
          return;
        }
      }

      if (widget.product.distributorId == null || widget.product.distributorId!.isEmpty) {
        return;
      }
      
      final response = await NetworkGuard.execute(() async {
        return await supabase
            .from('users')
            .select('whatsapp_number, role')
            .eq('display_name', widget.product.distributorId!)
            .maybeSingle();
      });

      if (response != null) {
        setState(() {
          if (response['whatsapp_number'] != null) {
            _phoneNumber = response['whatsapp_number'].toString();
          }
          _role = response['role']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading phone: $e');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  Future<void> _openWhatsApp() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) return;

    String phone = _phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      phone = '+2$phone';
    } else if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    final message = 'home.product_dialog.whatsapp_interest'.tr(namedArgs: {'name': widget.product.name});
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('distributors_feature.whatsapp_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offers.dialog.generic_error'.tr())),
        );
      }
    }
  }

  bool _isExpired(DateTime expirationDate) {
    final now = DateTime.now();
    return expirationDate.isBefore(DateTime(now.year, now.month + 1));
  }

  String formatPackageText(String package, BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer(
      builder: (context, ref, child) {
        final distributorsAsync = ref.watch(distributorsProvider);
        final currentDistributorName = distributorsAsync.maybeWhen(
          data: (distributors) {
            final dist = distributors.firstWhereOrNull((d) => d.id == widget.product.distributorUuid);
            return dist?.displayName ?? widget.product.distributorId;
          },
          orElse: () => widget.product.distributorId,
        );

        final containerColor = isDark
            ? Colors.grey.shade800.withOpacity(0.5)
            : Colors.white.withOpacity(0.8);
        final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
        final priceColor =
            isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
        final packageBgColor = isDark
            ? const Color.fromARGB(255, 216, 222, 249).withOpacity(0.1)
            : Colors.blue.shade50.withOpacity(0.8);
        final packageBorderColor = isDark
            ? const Color.fromARGB(255, 102, 126, 162)
            : Colors.blue.shade200;
        final imageBgColor = isDark
            ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
            : Colors.white.withOpacity(0.7);
        final backgroundColor =
            isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: isSmallScreen ? size.width * 0.95 : 400,
            height: size.height * 0.85,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.grey.shade600.withOpacity(0.3)
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
                          Row(
                            children: [
                              if (widget.product.distributorUuid != null) ...[
                                GestureDetector(
                                  onTap: () {
                                    if (_role == 'doctor') {
                                      UserDetailsSheet.show(context, ref, widget.product.distributorUuid!);
                                    } else {
                                      DistributorDetailsSheet.show(context, widget.product.distributorUuid!);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _role == 'doctor' ? Icons.person : Icons.location_on,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              GestureDetector(
                                onTap: () async {
                                  if (_role == 'doctor') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('تنبيه'),
                                        content: const Text('هذا المنتج تمت إضافته بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('حسناً'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  if (currentDistributorName != null) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator()),
                                    );
                                    await Future.delayed(const Duration(milliseconds: 400));
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) => DrawerWrapper(
                                          distributorId: currentDistributorName,
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                        horizontal: 16, vertical: 8),
                                                                    constraints: const BoxConstraints(maxWidth: 180),
                                                                    decoration: BoxDecoration(
                                                                      color: theme.colorScheme.primary,
                                                                      borderRadius: BorderRadius.circular(20),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: theme.colorScheme.primary
                                                                              .withOpacity(0.3),
                                                                          blurRadius: 8,
                                                                          offset: const Offset(0, 3),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Text(
                                                                      currentDistributorName ??
                                                                          'home.product_dialog.unknown_distributor'.tr(),
                                                                      style: TextStyle(
                                                                        color: theme.colorScheme.onPrimary,
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.product.company != null && widget.product.company!.isNotEmpty)
                        Text(
                          widget.product.company!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.product.activePrinciple != null &&
                          widget.product.activePrinciple!.isNotEmpty)
                        Text(
                          widget.product.activePrinciple!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: Text(
                              '${NumberFormatter.formatCompact(widget.product.price ?? 0)} ${'products.currency'.tr()}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: priceColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: RepaintBoundary(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: imageBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: CachedNetworkImage(
                              imageUrl: widget.product.imageUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 800,
                              memCacheHeight: 800,
                              placeholder: (context, url) => const Center(
                                child: ImageLoadingIndicator(size: 50),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.broken_image_outlined,
                                size: 60,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'home.product_dialog.active_principle'.tr(),
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
                            const TextSpan(
                              text: '',
                              style: TextStyle(color: Colors.transparent),
                            ),
                            TextSpan(
                              text: widget.product.activePrinciple ?? 'distributors_feature.products_screen.undefined'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.expirationDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isExpired(widget.expirationDate!)
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isExpired(widget.expirationDate!)
                                    ? Icons.warning_rounded
                                    : Icons.schedule_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'products.expiration_date'.tr(namedArgs: {'date': DateFormat('MM/yyyy').format(widget.expirationDate!)}),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.expirationDate != null) const SizedBox(height: 20),
                      if (widget.product.selectedPackage != null &&
                          widget.product.selectedPackage!.isNotEmpty)
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
                                    formatPackageText(widget.product.selectedPackage!, context),
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
                      if ((currentDistributorName != null && currentDistributorName.isNotEmpty) || (widget.product.distributorUuid != null && widget.product.distributorUuid!.isNotEmpty)) ...[
                        const SizedBox(height: 30),
                        Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingPhone || _phoneNumber == null
                                  ? null
                                  : _openWhatsApp,
                              icon: _isLoadingPhone
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_rounded,
                                        size: 22,
                                      ),
                                    ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLoadingPhone
                                          ? 'settings_feature.loading'.tr()
                                          : _phoneNumber == null
                                              ? 'offers.dialog.phone_not_available'.tr()
                                              : 'offers.dialog.contact_whatsapp'.tr(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!_isLoadingPhone && _phoneNumber != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.phone_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xFF25D366).withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dialog لعرض تفاصيل العرض
Future<void> showOfferProductDialog(
  BuildContext context,
  ProductModel offer, {
  DateTime? expirationDate,
}) {
  return showDialog(
    context: context,
    builder: (context) => _OfferProductDialog(
      offer: offer,
      expirationDate: expirationDate,
    ),
  );
}

class _OfferProductDialog extends StatefulWidget {
  const _OfferProductDialog({
    required this.offer,
    this.expirationDate,
  });

  final ProductModel offer;
  final DateTime? expirationDate;

  @override
  State<_OfferProductDialog> createState() => _OfferProductDialogState();
}

class _OfferProductDialogState extends State<_OfferProductDialog> {
  String? _phoneNumber;
  String? _role;
  bool _isLoadingPhone = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    setState(() => _isLoadingPhone = true);
    try {
      final supabase = Supabase.instance.client;

      if (widget.offer.distributorUuid != null && widget.offer.distributorUuid!.isNotEmpty) {
        final response = await NetworkGuard.execute(() async {
          return await supabase
              .from('users')
              .select('whatsapp_number, role')
              .eq('id', widget.offer.distributorUuid!)
              .maybeSingle();
        });

        if (response != null) {
          setState(() {
            if (response['whatsapp_number'] != null) {
              _phoneNumber = response['whatsapp_number'].toString();
            }
            _role = response['role']?.toString();
          });
          return;
        }
      }
      
      if (widget.offer.distributorId == null || widget.offer.distributorId!.isEmpty) {
        return;
      }
      
      final response = await NetworkGuard.execute(() async {
        return await supabase
            .from('users')
            .select('whatsapp_number, role')
            .eq('display_name', widget.offer.distributorId!)
            .maybeSingle();
      });

      if (response != null) {
        setState(() {
          if (response['whatsapp_number'] != null) {
            _phoneNumber = response['whatsapp_number'].toString();
          }
          _role = response['role']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading phone: $e');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  Future<void> _openWhatsApp() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) return;

    String phone = _phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      phone = '+2$phone';
    } else if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    final message = 'home.product_dialog.whatsapp_interest'.tr(namedArgs: {'name': widget.offer.name});
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('distributors_feature.whatsapp_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offers.dialog.generic_error'.tr())),
        );
      }
    }
  }

  bool _isExpired(DateTime expirationDate) {
    final now = DateTime.now();
    return expirationDate.isBefore(DateTime(now.year, now.month + 1));
  }

  String formatPackageText(String package, BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer(
      builder: (context, ref, child) {
        final distributorsAsync = ref.watch(distributorsProvider);
        final currentDistributorName = distributorsAsync.maybeWhen(
          data: (distributors) {
            final dist = distributors.firstWhereOrNull((d) => d.id == widget.offer.distributorUuid);
            return dist?.displayName ?? widget.offer.distributorId;
          },
          orElse: () => widget.offer.distributorId,
        );

        final containerColor = isDark
            ? Colors.grey.shade800.withOpacity(0.5)
            : Colors.white.withOpacity(0.8);
        final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
        final priceColor =
            isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
        final packageBgColor = isDark
            ? const Color.fromARGB(255, 216, 222, 249).withOpacity(0.1)
            : Colors.blue.shade50.withOpacity(0.8);
        final packageBorderColor = isDark
            ? const Color.fromARGB(255, 102, 126, 162)
            : Colors.blue.shade200;
        final imageBgColor = isDark
            ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
            : Colors.white.withOpacity(0.7);
        final backgroundColor =
            isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: isSmallScreen ? size.width * 0.95 : 400,
            height: size.height * 0.85,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.grey.shade600.withOpacity(0.3)
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
                          Row(
                            children: [
                              if (widget.offer.distributorUuid != null) ...[
                                GestureDetector(
                                  onTap: () {
                                    if (_role == 'doctor') {
                                      UserDetailsSheet.show(context, ref, widget.offer.distributorUuid!);
                                    } else {
                                      DistributorDetailsSheet.show(context, widget.offer.distributorUuid!);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _role == 'doctor' ? Icons.person : Icons.location_on,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.orange.shade700.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_offer_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'offers.dialog.special_offer'.tr(),
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.offer.company != null && widget.offer.company!.isNotEmpty)
                        Text(
                          widget.offer.company!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        widget.offer.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.offer.activePrinciple != null &&
                          widget.offer.activePrinciple!.isNotEmpty)
                        Text(
                          widget.offer.activePrinciple!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: Text(
                              '${NumberFormatter.formatCompact(widget.offer.price ?? 0)} ${'products.currency'.tr()}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: priceColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (currentDistributorName != null && currentDistributorName.isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                if (_role == 'doctor') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('تنبيه'),
                                      content: const Text('هذا العرض تمت إضافته بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('حسناً'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(child: CircularProgressIndicator()),
                                );
                                await Future.delayed(const Duration(milliseconds: 400));
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => DrawerWrapper(
                                      distributorId: currentDistributorName,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                constraints: const BoxConstraints(maxWidth: 120),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.store_outlined,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        currentDistributorName,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: RepaintBoundary(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: imageBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: CachedNetworkImage(
                              imageUrl: widget.offer.imageUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: 800,
                              memCacheHeight: 800,
                              placeholder: (context, url) => const Center(
                                child: ImageLoadingIndicator(size: 50),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.broken_image_outlined,
                                size: 60,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.expirationDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isExpired(widget.expirationDate!)
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isExpired(widget.expirationDate!)
                                    ? Icons.warning_rounded
                                    : Icons.schedule_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'products.expiration_date'.tr(namedArgs: {'date': DateFormat('MM/yyyy').format(widget.expirationDate!)}),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.expirationDate != null) const SizedBox(height: 20),
                      Text(
                        'home.product_dialog.active_principle'.tr(),
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
                            const TextSpan(
                              text: '',
                              style: TextStyle(color: Colors.transparent),
                            ),
                            TextSpan(
                              text: widget.offer.activePrinciple ?? 'distributors_feature.products_screen.undefined'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.offer.selectedPackage != null &&
                          widget.offer.selectedPackage!.isNotEmpty)
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
                                    formatPackageText(widget.offer.selectedPackage!, context),
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
                      if (widget.offer.description != null && widget.offer.description!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'offers.dialog.description'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            widget.offer.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if ((currentDistributorName != null && currentDistributorName.isNotEmpty) || (widget.offer.distributorUuid != null && widget.offer.distributorUuid!.isNotEmpty)) ...[
                        const SizedBox(height: 30),
                        Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingPhone || _phoneNumber == null
                                  ? null
                                  : _openWhatsApp,
                              icon: _isLoadingPhone
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_rounded,
                                        size: 22,
                                      ),
                                    ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLoadingPhone
                                          ? 'settings_feature.loading'.tr()
                                          : _phoneNumber == null
                                              ? 'offers.dialog.phone_not_available'.tr()
                                              : 'offers.dialog.contact_whatsapp'.tr(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!_isLoadingPhone && _phoneNumber != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.phone_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xFF25D366).withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

/// Dialog لعرض تفاصيل الأداة الجراحية
Future<void> showSurgicalToolDialog(
  BuildContext context,
  ProductModel tool,
) {
  _incrementProductViews(tool.id, isSurgicalTool: true);
  return showDialog(
    context: context,
    builder: (context) => _SurgicalToolDialog(tool: tool),
  );
}

void _incrementProductViews(String productId, {String? distributorId, bool isSurgicalTool = false}) async {
  try {
    if (isSurgicalTool) {
      await NetworkGuard.execute(() async {
        await Supabase.instance.client.rpc('increment_surgical_tool_views', params: {
          'p_tool_id': productId,
        });
      });
    } else if (productId.startsWith('ocr_') && distributorId != null) {
      final ocrProductId = productId.substring(4);
      await NetworkGuard.execute(() async {
        await Supabase.instance.client.rpc('increment_ocr_product_views', params: {
          'p_distributor_id': distributorId,
          'p_ocr_product_id': ocrProductId,
        });
      });
    } else {
      await NetworkGuard.execute(() async {
        await Supabase.instance.client.rpc('increment_product_views', params: {
          'p_product_id': productId,
        });
      });
    }
  } catch (e) {
    debugPrint('Error incrementing views: $e');
  }
}

class _SurgicalToolDialog extends StatefulWidget {
  const _SurgicalToolDialog({required this.tool});

  final ProductModel tool;

  @override
  State<_SurgicalToolDialog> createState() => _SurgicalToolDialogState();
}

class _SurgicalToolDialogState extends State<_SurgicalToolDialog> {
  String? _phoneNumber;
  String? _role;
  bool _isLoadingPhone = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    setState(() => _isLoadingPhone = true);
    try {
      final supabase = Supabase.instance.client;

      if (widget.tool.distributorUuid != null && widget.tool.distributorUuid!.isNotEmpty) {
        final response = await NetworkGuard.execute(() async {
          return await supabase
              .from('users')
              .select('whatsapp_number, role')
              .eq('id', widget.tool.distributorUuid!)
              .maybeSingle();
        });

        if (response != null) {
          setState(() {
            if (response['whatsapp_number'] != null) {
              _phoneNumber = response['whatsapp_number'].toString();
            }
            _role = response['role']?.toString();
          });
          return;
        }
      }
      
      if (widget.tool.distributorId == null || widget.tool.distributorId!.isEmpty) {
        return;
      }
      
      final response = await NetworkGuard.execute(() async {
        return await supabase
            .from('users')
            .select('whatsapp_number, role')
            .eq('display_name', widget.tool.distributorId!)
            .maybeSingle();
      });

      if (response != null) {
        setState(() {
          if (response['whatsapp_number'] != null) {
            _phoneNumber = response['whatsapp_number'].toString();
          }
          _role = response['role']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading phone: $e');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  Future<void> _openWhatsApp() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) return;

    String phone = _phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      phone = '+2$phone';
    } else if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    final message = 'home.product_dialog.whatsapp_interest'.tr(namedArgs: {'name': widget.tool.name});
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('distributors_feature.whatsapp_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offers.dialog.generic_error'.tr())),
        );
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'جديد': return Colors.green;
      case 'مستعمل': return Colors.orange;
      case 'كسر زيرو': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'جديد': return Icons.new_releases_rounded;
      case 'مستعمل': return Icons.history_rounded;
      case 'كسر زيرو': return Icons.star_rounded;
      default: return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = widget.tool.activePrinciple;

    final backgroundColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);
    final containerColor = isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.white.withOpacity(0.8);
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
    final imageBgColor = isDark ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3) : Colors.white.withOpacity(0.7);

    return Consumer(
      builder: (context, ref, child) {
        final distributorsAsync = ref.watch(distributorsProvider);
        final currentDistributorName = distributorsAsync.maybeWhen(
          data: (distributors) {
            final dist = distributors.firstWhereOrNull((d) => d.id == widget.tool.distributorUuid);
            return dist?.displayName ?? widget.tool.distributorId;
          },
          orElse: () => widget.tool.distributorId,
        );

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
                color: isDark ? const Color.fromARGB(255, 53, 47, 47).withOpacity(0.3) : Colors.grey.shade200,
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
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          if (currentDistributorName != null && currentDistributorName.isNotEmpty)
                            Row(
                              children: [
                                if (widget.tool.distributorUuid != null) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (_role == 'doctor') {
                                        UserDetailsSheet.show(context, ref, widget.tool.distributorUuid!);
                                      } else {
                                        DistributorDetailsSheet.show(context, widget.tool.distributorUuid!);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _role == 'doctor' ? Icons.person : Icons.location_on,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    if (_role == 'doctor') {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('تنبيه'),
                                          content: const Text('هذه الأداة تمت إضافتها بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('حسناً'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DistributorSurgicalToolsScreen(
                                          distributorId: widget.tool.distributorUuid!,
                                          distributorName: currentDistributorName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.auto_stories_rounded, size: 16, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            currentDistributorName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.tool.company != null && widget.tool.company!.isNotEmpty)
                        Text(
                          widget.tool.company!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        widget.tool.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
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
                            imageUrl: widget.tool.imageUrl,
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) => Icon(
                              Icons.medical_services_outlined,
                              size: 60,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (status != null && status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getStatusIcon(status), size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'surgical_tools_feature.fields.status'.tr(namedArgs: {'status': status}),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (widget.tool.company != null && widget.tool.company!.isNotEmpty)
                        _buildInfoRow(Icons.business, 'surgical_tools_feature.fields.manufacturer'.tr(), widget.tool.company!),
                      if (widget.tool.price != null)
                        _buildInfoRow(Icons.sell, 'surgical_tools_feature.fields.price'.tr(), '${NumberFormatter.formatCompact(widget.tool.price!)} ${'products.currency'.tr()}'),
                      if (widget.tool.description != null && widget.tool.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.description, size: 20),
                            const SizedBox(width: 8),
                            Text('surgical_tools_feature.fields.description'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(widget.tool.description ?? '', style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => SurgicalToolDetailsScreen(tool: widget.tool)));
                                },
                                icon: const Icon(Icons.info_outline_rounded),
                                label: Text('surgical_tools_feature.actions.tool_details'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            if ((currentDistributorName != null && currentDistributorName.isNotEmpty) || (widget.tool.distributorUuid != null && widget.tool.distributorUuid!.isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoadingPhone || _phoneNumber == null ? null : _openWhatsApp,
                                  icon: _isLoadingPhone ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.chat_bubble_rounded),
                                  label: Text(_isLoadingPhone ? 'settings_feature.loading'.tr() : _phoneNumber == null ? 'offers.dialog.phone_not_available'.tr() : 'offers.dialog.contact_whatsapp'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog لعرض تفاصيل العرض مع زر الواتساب
Future<void> showOfferDialog(
  BuildContext context,
  ProductModel offer,
) {
  return showDialog(
    context: context,
    builder: (context) => _OfferDialog(offer: offer),
  );
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.offer});

  final ProductModel offer;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  String? _phoneNumber;
  String? _role;
  bool _isLoadingPhone = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    setState(() => _isLoadingPhone = true);
    try {
      final supabase = Supabase.instance.client;
      
      if (widget.offer.distributorUuid != null && widget.offer.distributorUuid!.isNotEmpty) {
        final response = await NetworkGuard.execute(() async {
          return await supabase
              .from('users')
              .select('whatsapp_number, role')
              .eq('id', widget.offer.distributorUuid!)
              .maybeSingle();
        });

        if (response != null) {
          setState(() {
            if (response['whatsapp_number'] != null) {
              _phoneNumber = response['whatsapp_number'].toString();
            }
            _role = response['role']?.toString();
          });
          return;
        }
      }

      if (widget.offer.distributorId == null || widget.offer.distributorId!.isEmpty) {
        return;
      }
      
      final response = await NetworkGuard.execute(() async {
        return await supabase
            .from('users')
            .select('whatsapp_number, role')
            .eq('display_name', widget.offer.distributorId!)
            .maybeSingle();
      });

      if (response != null) {
        setState(() {
          if (response['whatsapp_number'] != null) {
            _phoneNumber = response['whatsapp_number'].toString();
          }
          _role = response['role']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading phone: $e');
    } finally {
      setState(() => _isLoadingPhone = false);
    }
  }

  Future<void> _openWhatsApp() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) return;

    String phone = _phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      phone = '+2$phone';
    } else if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    final message = 'home.product_dialog.whatsapp_interest'.tr(namedArgs: {'name': widget.offer.name});
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('distributors_feature.whatsapp_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offers.dialog.generic_error'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer(
      builder: (context, ref, child) {
        final distributorsAsync = ref.watch(distributorsProvider);
        final currentDistributorName = distributorsAsync.maybeWhen(
          data: (distributors) {
            final dist = distributors.firstWhereOrNull((d) => d.id == widget.offer.distributorUuid);
            return dist?.displayName ?? widget.offer.distributorId;
          },
          orElse: () => widget.offer.distributorId,
        );

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text('offers.dialog.title'.tr(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(16),
                            child: CachedNetworkImage(
                              imageUrl: widget.offer.imageUrl,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) => Icon(Icons.inventory_outlined, size: 60, color: colorScheme.onSurface.withOpacity(0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(widget.offer.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (widget.offer.activePrinciple != null && widget.offer.activePrinciple!.isNotEmpty)
                          _buildInfoRow(Icons.science, 'offers.labels.active_principle'.tr(), widget.offer.activePrinciple!),
                        if (widget.offer.company != null && widget.offer.company!.isNotEmpty)
                          _buildInfoRow(Icons.business, 'offers.labels.company'.tr(), widget.offer.company!),
                        if (widget.offer.selectedPackage != null && widget.offer.selectedPackage!.isNotEmpty)
                          _buildInfoRow(Icons.inventory_2, 'offers.labels.package'.tr(), widget.offer.selectedPackage!),
                        if (widget.offer.price != null)
                          _buildInfoRow(Icons.sell, 'offers.labels.price'.tr(), '${NumberFormatter.formatCompact(widget.offer.price!)} ${'products.currency'.tr()}'),
                        if (currentDistributorName != null)
                          _buildInfoRow(Icons.store, 'offers.labels.distributor'.tr(), currentDistributorName, onTap: () async {
                            if (_role == 'doctor') {
                              showDialog(context: context, builder: (context) => AlertDialog(title: const Text('تنبيه'), content: const Text('هذا العرض تمت إضافته بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))]));
                              return;
                            }
                            showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                            await Future.delayed(const Duration(milliseconds: 400));
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => DrawerWrapper(distributorId: currentDistributorName)), (route) => false);
                          }),
                        if (widget.offer.description != null && widget.offer.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.description, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('offers.dialog.description'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(widget.offer.description!, style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if ((currentDistributorName != null && currentDistributorName.isNotEmpty) || (widget.offer.distributorUuid != null && widget.offer.distributorUuid!.isNotEmpty))
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingPhone || _phoneNumber == null ? null : _openWhatsApp,
                            icon: _isLoadingPhone ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.chat),
                            label: Text(_isLoadingPhone ? 'settings_feature.loading'.tr() : _phoneNumber == null ? 'offers.dialog.phone_not_available'.tr() : 'offers.dialog.contact_whatsapp'.tr()),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               BOOKS DIALOG                                 */
/* -------------------------------------------------------------------------- */

Future<void> showBookDialog(BuildContext context, Book book) {
  return showDialog(
    context: context,
    builder: (context) => _BookDialog(book: book),
  );
}

class _BookDialog extends ConsumerStatefulWidget {
  final Book book;
  const _BookDialog({required this.book});

  @override
  ConsumerState<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends ConsumerState<_BookDialog> {
  String? _fetchedName;
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    if (widget.book.userName != null && widget.book.userName != 'مستخدم') {
      return;
    }

    setState(() => _isLoadingName = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('display_name')
          .eq('id', widget.book.userId)
          .maybeSingle();

      if (response != null && response['display_name'] != null) {
        setState(() {
          _fetchedName = response['display_name'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading owner name: $e');
    } finally {
      setState(() => _isLoadingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final distributorsAsync = ref.watch(distributorsProvider);
    final owner = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == widget.book.userId);
    final ownerName = owner?.displayName ?? _fetchedName ?? widget.book.userName ?? 'مستخدم';

    // Increment views
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allBooksNotifierProvider.notifier).incrementViews(widget.book.id);
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: CachedNetworkImage(
                      imageUrl: widget.book.imageUrl,
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
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5), foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.book.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UserBooksScreen(userId: widget.book.userId, userName: ownerName)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.primary.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _isLoadingName 
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(ownerName, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
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
                        Text(widget.book.author, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(widget.book.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatChip(context, Icons.price_change, 'books_feature.price'.tr(), '${NumberFormatter.formatCompact(widget.book.price)} ${'products.currency'.tr()}', Colors.green),
                        const SizedBox(width: 12),
                        _buildStatChip(context, Icons.visibility, 'books_feature.views'.tr(), NumberFormatter.formatCompact(widget.book.views), colorScheme.primary),
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
                                  builder: (context) => BookDetailsScreen(book: widget.book),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded),
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
                              final url = Uri.parse('https://wa.me/${widget.book.phone}');
                              launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                            label: Text('books_feature.contact'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              COURSES DIALOG                                */
/* -------------------------------------------------------------------------- */

Future<void> showCourseDialog(BuildContext context, Course course) {
  return showDialog(
    context: context,
    builder: (context) => _CourseDialog(course: course),
  );
}

class _CourseDialog extends ConsumerStatefulWidget {
  final Course course;
  const _CourseDialog({required this.course});

  @override
  ConsumerState<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends ConsumerState<_CourseDialog> {
  String? _fetchedName;
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    if (widget.course.userName != null && widget.course.userName != 'مستخدم') {
      return;
    }

    setState(() => _isLoadingName = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('display_name')
          .eq('id', widget.course.userId)
          .maybeSingle();

      if (response != null && response['display_name'] != null) {
        setState(() {
          _fetchedName = response['display_name'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading owner name: $e');
    } finally {
      setState(() => _isLoadingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final distributorsAsync = ref.watch(distributorsProvider);
    final owner = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == widget.course.userId);
    final ownerName = owner?.displayName ?? _fetchedName ?? widget.course.userName ?? 'مستخدم';

    // Increment views
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allCoursesNotifierProvider.notifier).incrementViews(widget.course.id);
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: CachedNetworkImage(
                      imageUrl: widget.course.imageUrl,
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
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5), foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.course.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UserCoursesScreen(userId: widget.course.userId, userName: ownerName)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.primary.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _isLoadingName 
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(ownerName, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(widget.course.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatChip(context, Icons.price_change, 'courses_feature.price'.tr(), '${NumberFormatter.formatCompact(widget.course.price)} ${'products.currency'.tr()}', Colors.green),
                        const SizedBox(width: 12),
                        _buildStatChip(context, Icons.visibility, 'courses_feature.views'.tr(), NumberFormatter.formatCompact(widget.course.views), colorScheme.primary),
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
                                  builder: (context) => CourseDetailsScreen(course: widget.course),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded),
                            label: Text('courses_feature.course_details'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                              final url = Uri.parse('https://wa.me/${widget.course.phone}');
                              launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                            label: Text('courses_feature.contact'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}