import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/surgical_tools/presentation/screens/surgical_tool_details_screen.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'dart:ui' as ui;

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
      
      if (widget.product.distributorId == null || widget.product.distributorId!.isEmpty) {
        return;
      }
      
      final response = await supabase
          .from('users')
          .select('whatsapp_number')
          .eq('display_name', widget.product.distributorId!)
          .maybeSingle();

      if (response != null && response['whatsapp_number'] != null) {
        setState(() {
          _phoneNumber = response['whatsapp_number'].toString();
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

    final message = 'مرحباً، أنا مهتم بـ ${widget.product.name}';
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الواتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء فتح الواتساب')),
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
                              onTap: () => DistributorDetailsSheet.show(
                                  context, widget.product.distributorUuid!),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
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
                          ],
                          GestureDetector(
                            onTap: () {
                              if (widget.product.distributorId != null) {
                                Navigator.of(context).pop(); // Close the dialog
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => DrawerWrapper(
                                      distributorId:
                                          widget.product.distributorId,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
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
                                widget.product.distributorId ??
                                    'موزع غير معروف',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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
                          '${NumberFormatter.formatCompact(widget.product.price ?? 0)} ${'EGP'.tr()}',
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
                          text: widget.product.activePrinciple ?? 'غير محدد',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // === تاريخ الصلاحية ===
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
                            'تاريخ الصلاحية: ${DateFormat('MM/yyyy').format(widget.expirationDate!)}',
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
                  // === زر الواتساب ===
                  if (widget.product.distributorId != null && widget.product.distributorId!.isNotEmpty) ...[
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
                                      ? 'جاري التحميل...'
                                      : _phoneNumber == null
                                          ? 'رقم الواتساب غير متوفر'
                                          : 'تواصل عبر الواتساب',
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
      
      if (widget.offer.distributorId == null || widget.offer.distributorId!.isEmpty) {
        return;
      }
      
      final response = await supabase
          .from('users')
          .select('whatsapp_number')
          .eq('display_name', widget.offer.distributorId!)
          .maybeSingle();

      if (response != null && response['whatsapp_number'] != null) {
        setState(() {
          _phoneNumber = response['whatsapp_number'].toString();
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

    final message = 'مرحباً، أنا مهتم بـ ${widget.offer.name}';
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الواتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء فتح الواتساب')),
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
                              onTap: () => DistributorDetailsSheet.show(
                                  context, widget.offer.distributorUuid!),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
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
                          '${NumberFormatter.formatCompact(widget.offer.price ?? 0)} ${'EGP'.tr()}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: priceColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (widget.offer.distributorId != null && widget.offer.distributorId!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(); // Close the dialog
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => DrawerWrapper(
                                  distributorId: widget.offer.distributorId,
                                ),
                              ),
                              (route) => false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                                Text(
                                  widget.offer.distributorId!,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
                  // === تاريخ الصلاحية ===
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
                            'تاريخ الصلاحية: ${DateFormat('MM/yyyy').format(widget.expirationDate!)}',
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
                          text: widget.offer.activePrinciple ?? 'غير محدد',
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
                  // === وصف العرض ===
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
                                        ),                    const SizedBox(height: 12),
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
                  // === زر الواتساب ===
                  if (widget.offer.distributorId != null && widget.offer.distributorId!.isNotEmpty) ...[
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
                                      ? 'جاري التحميل...'
                                      : _phoneNumber == null
                                          ? 'رقم الواتساب غير متوفر'
                                          : 'تواصل عبر الواتساب',
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
}

/// Dialog لعرض تفاصيل الأداة الجراحية
Future<void> showSurgicalToolDialog(
  BuildContext context,
  ProductModel tool,
) {
  // حساب المشاهدة فور فتح الديالوج للأدوات الجراحية
  _incrementProductViews(tool.id, isSurgicalTool: true);
  
  return showDialog(
    context: context,
    builder: (context) => _SurgicalToolDialog(tool: tool),
  );
}

// دالة مساعدة لزيادة مشاهدات المنتج (Regular, OCR, Surgical)
void _incrementProductViews(String productId, {String? distributorId, bool isSurgicalTool = false}) {
  try {
    print('🔵 [Dialog] Incrementing views for product: $productId, surgical: $isSurgicalTool');
    
    // تحقق من نوع المنتج
    if (isSurgicalTool) {
      // أداة جراحية
      Supabase.instance.client.rpc('increment_surgical_tool_views', params: {
        'p_tool_id': productId,  // ✅ تم التعديل
      }).then((response) {
        print('✅ [Dialog] Surgical tool views incremented');
      }).catchError((error) {
        print('❌ [Dialog] Error incrementing surgical tool views: $error');
      });
    } else if (productId.startsWith('ocr_') && distributorId != null) {
      // منتج OCR
      final ocrProductId = productId.substring(4); // إزالة "ocr_" من البداية
      
      print('🔍 [OCR] distributorId: $distributorId');
      print('🔍 [OCR] original productId: $productId');
      print('🔍 [OCR] ocr_product_id (after removing prefix): $ocrProductId');
      
      Supabase.instance.client.rpc('increment_ocr_product_views', params: {
        'p_distributor_id': distributorId,  // ✅ صحيح
        'p_ocr_product_id': ocrProductId,   // ✅ صحيح
      }).then((response) {
        print('✅ [Dialog] OCR product views incremented for: $ocrProductId');
        print('✅ [Dialog] Response: $response');
      }).catchError((error) {
        print('❌ [Dialog] Error incrementing OCR product views: $error');
        print('❌ [Dialog] Failed for distributorId: $distributorId, ocrProductId: $ocrProductId');
      });
    } else {
      // منتج عادي
      Supabase.instance.client.rpc('increment_product_views', params: {
        'p_product_id': productId,  // ✅ تم التعديل
      }).then((response) {
        print('✅ [Dialog] Regular product views incremented for ID: $productId');
      }).catchError((error) {
        print('❌ [Dialog] Error incrementing regular product views: $error');
      });
    }
  } catch (e) {
    print('❌ [Dialog] خطأ في زيادة مشاهدات المنتج: $e');
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
      
      if (widget.tool.distributorId == null || widget.tool.distributorId!.isEmpty) {
        return;
      }
      
      final response = await supabase
          .from('users')
          .select('whatsapp_number')
          .eq('display_name', widget.tool.distributorId!)
          .maybeSingle();

      if (response != null && response['whatsapp_number'] != null) {
        setState(() {
          _phoneNumber = response['whatsapp_number'].toString();
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

    final message = 'مرحباً، أنا مهتم بـ ${widget.tool.name}';
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الواتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء فتح الواتساب')),
        );
      }
    }
  }

  Color _getStatusColor(String? status) {
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

  IconData _getStatusIcon(String? status) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = widget.tool.activePrinciple;

    // ألوان حسب الثيم
    final backgroundColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);
    final containerColor = isDark
        ? Colors.grey.shade800.withOpacity(0.5)
        : Colors.white.withOpacity(0.8);
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
    final imageBgColor = isDark
        ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
        : Colors.white.withOpacity(0.7);

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
                  // === Header مع زر الرجوع والموزع ===
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
                      if (widget.tool.distributorId != null &&
                          widget.tool.distributorId!.isNotEmpty)
                        Row(
                          children: [
                            if (widget.tool.distributorUuid != null) ...[
                              GestureDetector(
                                onTap: () => DistributorDetailsSheet.show(
                                    context, widget.tool.distributorUuid!),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
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
                            ],
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop(); // Close the dialog
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => DrawerWrapper(
                                      distributorId: widget.tool.distributorId,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                                  widget.tool.distributorId!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // === الشركة ===
                  if (widget.tool.company != null && widget.tool.company!.isNotEmpty)
                    Text(
                      widget.tool.company!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // === اسم الأداة ===
                  Text(
                    widget.tool.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // === صورة الأداة ===
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

                  // === الحالة ===
                  if (status != null && status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الحالة: $status',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                    // الشركة
                    if (widget.tool.company != null && widget.tool.company!.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.business,
                        'الشركة',
                        widget.tool.company!,
                      ),

                    // السعر
                    if (widget.tool.price != null)
                      _buildInfoRow(
                        context,
                        Icons.sell,
                        'السعر',
                        '${NumberFormatter.formatCompact(widget.tool.price!)} ج.م',
                      ),

                    // الوصف
                    if (widget.tool.description != null && widget.tool.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 20,
                            
                            
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الوصف',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.tool.description ?? '',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],

                    // === أزرار العمل ===
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // زر تفاصيل الأداة
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SurgicalToolDetailsScreen(tool: widget.tool),
                                  ),
                                );
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 20,
                                ),
                              ),
                              label: const Text(
                                'تفاصيل الأداة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                          ),
                          
                          // زر الواتساب
                          if (widget.tool.distributorId != null && widget.tool.distributorId!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
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
                                          size: 20,
                                        ),
                                      ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _isLoadingPhone
                                            ? 'جاري التحميل...'
                                            : _phoneNumber == null
                                                ? 'رقم الواتساب غير متوفر'
                                                : 'تواصل عبر الواتساب',
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
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  shadowColor: const Color(0xFF25D366).withOpacity(0.5),
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
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      
      // جلب رقم الواتساب من جدول users بناءً على display_name
      if (widget.offer.distributorId == null || widget.offer.distributorId!.isEmpty) {
        return;
      }
      
      final response = await supabase
          .from('users')
          .select('whatsapp_number')
          .eq('display_name', widget.offer.distributorId!)
          .maybeSingle();

      if (response != null && response['whatsapp_number'] != null) {
        setState(() {
          _phoneNumber = response['whatsapp_number'].toString();
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

    // تنظيف رقم الهاتف
    String phone = _phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    
    // إضافة كود مصر إذا لم يكن موجوداً
    if (!phone.startsWith('+') && !phone.startsWith('00')) {
      phone = '+2$phone';
    } else if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    final message = 'مرحباً، أنا مهتم بـ ${widget.offer.name}';
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الواتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء فتح الواتساب')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'offers.dialog.title'.tr(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الصورة
                    Center(
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: CachedNetworkImage(
                          imageUrl: widget.offer.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => Icon(
                            Icons.inventory_outlined,
                            size: 60,
                            color: colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // اسم المنتج
                    Text(
                      widget.offer.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // المادة الفعالة
                    if (widget.offer.activePrinciple != null &&
                        widget.offer.activePrinciple!.isNotEmpty)
                      _buildInfoRow(
                        Icons.science,
                        'المادة الفعالة',
                        widget.offer.activePrinciple!,
                      ),

                    // الشركة
                    if (widget.offer.company != null &&
                        widget.offer.company!.isNotEmpty)
                      _buildInfoRow(
                        Icons.business,
                        'الشركة',
                        widget.offer.company!,
                      ),

                    // Package
                    if (widget.offer.selectedPackage != null &&
                        widget.offer.selectedPackage!.isNotEmpty)
                      _buildInfoRow(
                        Icons.inventory_2,
                        'العبوة',
                        widget.offer.selectedPackage!,
                      ),

                    // السعر
                    if (widget.offer.price != null)
                      _buildInfoRow(
                        Icons.sell,
                        'السعر',
                        '${NumberFormatter.formatCompact(widget.offer.price!)} ج.م',
                      ),

                    // الموزع
                    if (widget.offer.distributorId != null)
                      _buildInfoRow(
                        Icons.store,
                        'الموزع',
                        widget.offer.distributorId!,
                      ),

                    // الوصف
                    if (widget.offer.description != null && widget.offer.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الوصف',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.offer.description ?? '',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // WhatsApp Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
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
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            size: 20,
                          ),
                        ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLoadingPhone
                            ? 'جاري التحميل...'
                            : _phoneNumber == null
                                ? 'رقم الواتساب غير متوفر'
                                : 'تواصل عبر الواتساب',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
