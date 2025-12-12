// ignore_for_file: unused_import

import "package:collection/collection.dart";
import "package:fieldawy_store/core/caching/caching_service.dart";
// lib/features/distributors/presentation/screens/distributor_products_screen.dart

import "dart:ui" as ui;
import "dart:async";

import "package:cached_network_image/cached_network_image.dart";
import "package:easy_localization/easy_localization.dart";
import "package:fieldawy_store/features/distributors/domain/distributor_model.dart";

import "package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart";
import "package:fieldawy_store/features/orders/presentation/screens/distributor_order_details_screen.dart";
import "package:fieldawy_store/features/orders/application/orders_provider.dart";
import "package:fieldawy_store/features/products/data/product_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";
import "package:fieldawy_store/widgets/shimmer_loader.dart";

import "../../../products/domain/product_model.dart";
import "package:awesome_snackbar_content/awesome_snackbar_content.dart";
import "package:fieldawy_store/features/products/application/favorites_provider.dart";
import "package:fieldawy_store/main.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:fieldawy_store/features/authentication/domain/user_model.dart";
import "package:fieldawy_store/services/distributor_subscription_service.dart";


/* -------------------------------------------------------------------------- */
/*                               DATA PROVIDERS                               */
/* -------------------------------------------------------------------------- */

// Provider to get products for a specific distributor from Supabase
final distributorProductsProvider =
    FutureProvider.family<List<ProductModel>, String>(
        (ref, distributorId) async {
  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  final lastModified = ref.watch(productDataLastModifiedProvider);
  final cacheKey = 'distributor_products_edge_${distributorId}_$lastModified';

  // 1. Check local cache
  final cached = cache.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    return cached.map((data) => ProductModel.fromMap(Map<String, dynamic>.from(data))).toList();
  }

  // 2. Invoke Edge Function with the distributorId
  final response = await supabase.functions.invoke(
    'get-distributor-products',
    body: {'distributorId': distributorId},
  );

  if (response.data == null) {
    throw 'Failed to fetch products for distributor $distributorId';
  }

  // 3. Parse and return (handle both regular and OCR products)
  final List<dynamic> data = response.data;
  final products = data.map((productData) {
    try {
      final d = Map<String, dynamic>.from(productData);
      
      // Check if this is an OCR product (has availablePackages field)
      if (d.containsKey('availablePackages')) {
        // OCR product - already in camelCase from Edge Function
        // إضافة prefix 'ocr_' لتمييز OCR products في view tracking
        return ProductModel(
          id: 'ocr_${d['id']?.toString() ?? ''}',
          name: d['name']?.toString() ?? '',
          company: d['company']?.toString() ?? '',
          activePrinciple: d['activePrinciple']?.toString() ?? '',
          imageUrl: d['imageUrl']?.toString() ?? '',
          availablePackages: (d['availablePackages'] as List?)?.map((e) => e.toString()).toList() ?? [],
          selectedPackage: d['selectedPackage']?.toString(),
          price: (d['price'] as num?)?.toDouble(),
          oldPrice: (d['oldPrice'] as num?)?.toDouble(),
          priceUpdatedAt: d['priceUpdatedAt'] != null ? DateTime.tryParse(d['priceUpdatedAt']) : null,
          distributorId: d['distributorId']?.toString(),
        );
      } else {
        // Regular product - use fromMap for snake_case fields
        return ProductModel.fromMap(d).copyWith(
          price: (d['price'] as num?)?.toDouble(),
          oldPrice: (d['oldPrice'] as num?)?.toDouble(),
          priceUpdatedAt: d['priceUpdatedAt'] != null ? DateTime.tryParse(d['priceUpdatedAt']) : null,
          selectedPackage: d['selectedPackage']?.toString(),
          distributorId: d['distributorId']?.toString(),
        );
      }
    } catch (e) {
      print('Error parsing product: $e');
      return null;
    }
  }).whereType<ProductModel>().toList();

  // 4. Save raw data to local cache
  cache.set(cacheKey, data, duration: const Duration(minutes: 30));

  return products;
});

/* -------------------------------------------------------------------------- */
/*                               MAIN  SCREEN                                 */
/* -------------------------------------------------------------------------- */

class DistributorProductsScreen extends HookConsumerWidget {
  DistributorProductsScreen({
    super.key,
    this.distributor,
    this.distributorId,
    this.distributorName,
  }) {
    if (distributor == null &&
        (distributorId == null || distributorName == null)) {
      throw StateError(
          'Either distributor or both distributorId and distributorName must be provided');
    }
  }
  
  final DistributorModel? distributor;
  final String? distributorId;
  final String? distributorName;
  
  String get _distributorId {
    final id = distributor?.id ?? distributorId;
    if (id == null) {
      throw StateError('Distributor id is required but was not provided');
    }
    return id;
  }

  String get _distributorName {
    final name = distributor?.displayName ?? distributorName;
    if (name == null) {
      throw StateError('Distributor name is required but was not provided');
    }
    return name;
  }

  // دالة لجلب تفاصيل الموزع الكاملة
  Future<DistributorModel?> _fetchDistributorDetails(String id) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke('get-distributors');
      
      if (response.data != null) {
        final List<dynamic> data = response.data;
        final distributorData = data.firstWhereOrNull((d) => d['id'] == id);
        
        if (distributorData != null) {
          return DistributorModel.fromMap(Map<String, dynamic>.from(distributorData));
        }
      }
    } catch (e) {
      print('Error fetching distributor details: $e');
    }
    return null;
  }

  // عرض تفاصيل الموزع
  void _showDistributorDetails(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    
    DistributorModel? currentDistributor = distributor;
    
    // إذا لم يكن لدينا كائن الموزع الكامل، نحاول جلبه
    if (currentDistributor == null) {
      // إظهار مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      currentDistributor = await _fetchDistributorDetails(_distributorId);
      
      // إغلاق مؤشر التحميل
      if (context.mounted) Navigator.of(context).pop();
      
      if (currentDistributor == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('distributors_feature.products_screen.load_error'.tr())),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildDistributorDetailsDialog(context, theme, currentDistributor!),
      );
    }
  }

  Widget _buildDistributorDetailsDialog(
      BuildContext context, ThemeData theme, DistributorModel distributor) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: distributor.photoURL != null &&
                            distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                                child: ImageLoadingIndicator(size: 32)),
                            errorWidget: (context, url, error) => Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant),
                          )
                        : Icon(Icons.person_rounded,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  distributor.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    distributor.distributorType == 'company'
                        ? 'distributionCompany'.tr()
                        : 'individualDistributor'.tr(),
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.2)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (distributor.distributionMethod != null)
                  _buildDetailListTile(
                    theme,
                    Icons.local_shipping_rounded,
                    'distributionMethod'.tr(),
                    distributor.distributionMethod == 'direct_distribution'
                        ? 'directDistribution'.tr()
                        : distributor.distributionMethod == 'order_delivery'
                            ? 'orderDelivery'.tr()
                            : 'both'.tr(),
                  ),
                if (distributor.governorates != null && distributor.governorates!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.map_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Coverage Areas'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 56.0), // Indent to align with text
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: distributor.governorates!.map((gov) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    gov,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )).toList(),
                              ),
                              if (distributor.centers != null && distributor.centers!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: distributor.centers!.map((center) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      center,
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildDetailListTile(
                  theme,
                  Icons.inventory_2_rounded,
                  'numberOfProducts'.tr(),
                  'productCount'
                      .tr(args: [distributor.productCount.toString()]),
                ),
              ],
            ),
          ),
          if (distributor.whatsappNumber != null &&
              distributor.whatsappNumber!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _openWhatsApp(context, distributor);
                  },
                  icon: const FaIcon(FontAwesomeIcons.whatsapp,
                      color: Colors.white, size: 20),
                  label: Text('contactViaWhatsapp'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailListTile(
      ThemeData theme, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(
      BuildContext context, DistributorModel distributor) async {
    final phoneNumber = distributor.whatsappNumber;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('phoneNumberNotAvailable'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final message = Uri.encodeComponent('whatsappInquiry'.tr());
    final whatsappUrl = 'https://wa.me/20$cleanPhone?text=$message';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('couldNotOpenWhatsApp'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'ok'.tr(),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // دالة مساعدة لحساب نقاط الأولوية في البحث
  int _calculateSearchScore(ProductModel product, String query) {
    int score = 0;

    final productName = product.name.toLowerCase();
    final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
    final distributorName = (product.distributorId ?? '').toLowerCase();
    final company = (product.company ?? '').toLowerCase();
    final packageSize = (product.selectedPackage ?? '').toLowerCase();
    final description = (product.description ?? '').toLowerCase();

    // نقاط عالية للمطابقات المهمة
    if (productName.contains(query)) score += 10;
    if (activePrinciple.contains(query)) score += 8;
    if (distributorName.contains(query)) score += 6;

    // نقاط متوسطة للمطابقات الثانوية
    if (company.contains(query)) score += 4;
    if (packageSize.contains(query)) score += 2;
    if (description.contains(query)) score += 2;

    // نقاط إضافية للمطابقة في بداية النص
    if (productName.startsWith(query)) score += 5;
    if (activePrinciple.startsWith(query)) score += 3;
    if (distributorName.startsWith(query)) score += 3;

    return score;
  }

  // دالة لإظهار ديالوج تفاصيل المنتج مع أنيميشن احترافي
  void _showProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: _buildProductDetailDialog(context, ref, product),
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

// بناء ديالوج تفاصيل المنتج - مُصحح
  // بناء ديالوج تفاصيل المنتج - مع دعم الثيم الداكن والفاتح
  Widget _buildProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    // ألوان حسب الثيم
    final backgroundGradient = isDark
        ? const LinearGradient(
            colors: [
              Color(0xFF1E1E2E), // داكن بنفسجي
              Color(0xFF2A2A3A), // داكن رمادي
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [
              Color(0xFFE3F2FD), // أزرق فاتح (التصميم الأصلي)
              Color(0xFFF8FDFF), // أبيض مع لمسة زرقاء
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final containerColor = isDark
        ? Colors.grey.shade800.withAlpha(128)
        : Colors.white.withAlpha(204);
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
    final priceColor =
        isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
    final favoriteColor =
        isDark ? Colors.redAccent.shade100 : Colors.red.shade400;
    final packageBgColor = isDark
        ? const Color.fromARGB(255, 239, 241, 251).withAlpha(26)
        : Colors.blue.shade50.withAlpha(204);
    final packageBorderColor =
        isDark ? Colors.grey.shade600 : Colors.blue.shade200;
    final imageBgColor = isDark
        ? const Color.fromARGB(255, 21, 15, 15).withAlpha(77)
        : Colors.white.withAlpha(179);

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
              color: isDark
                  ? Colors.black.withAlpha(77)
                  : Colors.black.withAlpha(26),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.grey.shade600.withAlpha(77)
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
                  // === Header مع badge الموزع ===
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
                      // Badge اسم الموزع
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                          _distributorName,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // === اسم الشركة ===
                  if (product.company != null && product.company!.isNotEmpty)
                    Text(
                      product.company!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(179),
                        fontWeight: FontWeight.w500,
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
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // === السعر مع أيقونة القلب ===
                  Row(
                    children: [
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          '${product.price?.toStringAsFixed(0) ?? 0} ${'EGP'.tr()}',
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
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? Colors.red : favoriteColor,
                              ),
                              onPressed: () {
                                ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavorite(product);
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: isFavorite ? 'تم الحذف' : 'نجاح',
                                      message: isFavorite
                                          ? 'تمت إزالة ${product.name} من المفضلة'
                                          : 'addedToFavorites'
                                              .tr(args: [product.name]),
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
                          color: theme.colorScheme.onSurface.withAlpha(102),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === وصف المنتج ===
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

                  // === حجم العبوة مُصغر بدون كلمة Size ===
                  if (product.selectedPackage != null &&
                      product.selectedPackage!.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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

                  // === رسالة التطبيق - مُكبرة ===
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync =
        ref.watch(distributorProductsProvider(_distributorId));
    final searchQuery = useState<String>('');
    final debouncedSearchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final ghostText = useState<String>('');
    final fullSuggestion = useState<String>('');
    
    useEffect(() {
      Timer? debounce;
      void listener() {
        if (debounce?.isActive ?? false) debounce!.cancel();
        debounce = Timer(const Duration(milliseconds: 500), () {
          debouncedSearchQuery.value = searchController.text;
        });
      }
      
      searchController.addListener(listener);
      return () {
        debounce?.cancel();
        searchController.removeListener(listener);
      };
    }, [searchController]);

    final order = ref.watch(orderProvider);
    final distributorOrderItems = order.where((item) => item.product.distributorId == _distributorName).toList();

    return GestureDetector(
      onTap: () {
        if (!productsAsync.isLoading) {
          searchFocusNode.unfocus();
        }
      },
      child: Scaffold(
        floatingActionButton: distributorOrderItems.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DistributorOrderDetailsScreen(
                        distributorName: _distributorName,
                        products: distributorOrderItems,
                      ),
                    ),
                  );
                },
                label: Text('distributors_feature.products_screen.view_order'.tr()),
                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
        appBar: AppBar(
          title: Text('distributors_feature.products_screen.title'.tr(namedArgs: {'name': _distributorName})),
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'distributors_feature.products_screen.details_tooltip'.tr(),
              onPressed: () => _showDistributorDetails(context, ref),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 15.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (value) {
                          searchQuery.value = value;
                          if (value.isNotEmpty) {
                            productsAsync.whenData((products) {
                              final filtered = products.where((product) {
                                final productName = product.name.toLowerCase();
                                return productName.startsWith(value.toLowerCase());
                              }).toList();
                              
                              if (filtered.isNotEmpty) {
                                final suggestion = filtered.first;
                                ghostText.value = suggestion.name;
                                fullSuggestion.value = suggestion.name;
                              } else {
                                ghostText.value = '';
                                fullSuggestion.value = '';
                              }
                            });
                          } else {
                            ghostText.value = '';
                            fullSuggestion.value = '';
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'ابحث عن دواء، مادة فعالة...',
                          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.primary,
                            size: 25,
                          ),
                          suffixIcon: searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    searchController.clear();
                                    searchQuery.value = '';
                                    debouncedSearchQuery.value = '';
                                    ghostText.value = '';
                                    fullSuggestion.value = '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    if (ghostText.value.isNotEmpty)
                      Positioned(
                        top: 19,
                        right: 55,
                        child: GestureDetector(
                          onTap: () {
                            if (fullSuggestion.value.isNotEmpty) {
                              searchController.text = fullSuggestion.value;
                              searchQuery.value = fullSuggestion.value;
                              debouncedSearchQuery.value = fullSuggestion.value;
                              ghostText.value = '';
                              fullSuggestion.value = '';
                              searchFocusNode.unfocus();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.1)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ghostText.value,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(distributorProductsProvider(_distributorId).future),
          child: productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color:
                            Theme.of(context).colorScheme.primary.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'distributors_feature.products_screen.no_products'.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(179),
                            ),
                      ),
                    ],
                  ),
                );
              }

              List<ProductModel> filteredProducts;
              if (debouncedSearchQuery.value.isEmpty) {
                filteredProducts = products;
              } else {
                filteredProducts = products.where((product) {
                  final query = debouncedSearchQuery.value.toLowerCase().trim();
                  final productName = product.name.toLowerCase();
                  final distributorName =
                      (product.distributorId ?? '').toLowerCase();
                  final activePrinciple =
                      (product.activePrinciple ?? '').toLowerCase();
                  final packageSize =
                      (product.selectedPackage ?? '').toLowerCase();
                  final company = (product.company ?? '').toLowerCase();
                  final description = (product.description ?? '').toLowerCase();
                  final action = (product.action ?? '').toLowerCase();

                  bool highPriorityMatch = productName.contains(query) ||
                      activePrinciple.contains(query) ||
                      distributorName.contains(query);
                  bool mediumPriorityMatch = company.contains(query) ||
                      packageSize.contains(query) ||
                      description.contains(query);
                  bool lowPriorityMatch = action.contains(query);

                  return highPriorityMatch ||
                      mediumPriorityMatch ||
                      lowPriorityMatch;
                }).toList();

                filteredProducts.sort((a, b) {
                  final query = debouncedSearchQuery.value.toLowerCase().trim();
                  int scoreA = _calculateSearchScore(a, query);
                  int scoreB = _calculateSearchScore(b, query);
                  return scoreB.compareTo(scoreA);
                });
              }

              return Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8, top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Let the row be as small as its children
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'distributors_feature.products_screen.products_count'.tr(namedArgs: {'count': filteredProducts.length.toString()}),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        filteredProducts.isEmpty && debouncedSearchQuery.value.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off_outlined,
                                      size: 60,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(128),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'distributors_feature.products_screen.no_search_results'.tr(namedArgs: {'query': debouncedSearchQuery.value}),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withAlpha(179),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'distributors_feature.products_screen.search_tips'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withAlpha(128),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        searchController.clear();
                                        searchQuery.value = '';
                                        debouncedSearchQuery.value = '';
                                        ghostText.value = '';
                                        fullSuggestion.value = '';
                                      },
                                      icon: const Icon(Icons.clear, size: 18),
                                      label: Text('distributors_feature.products_screen.clear_search'.tr()),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 1.0),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8.0,
                                  mainAxisSpacing: 8.0,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];

                                  return _buildProductCard(context, ref, product,
                                      debouncedSearchQuery.value, _distributorName);
                                },
                              ),
                  ),
                ],
              );
            },
            loading: () => ListView.builder(
              itemCount: 6,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ProductCardShimmer(),
                );
              },
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('distributors_feature.products_screen.error_occurred'.tr(namedArgs: {'error': error.toString()}),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(distributorProductsProvider(_distributorId));
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('distributors_feature.retry'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref,
      ProductModel product, String searchQuery, String distributorName) {
    final order = ref.watch(orderProvider);
    final orderItemInCart = order.firstWhereOrNull((item) =>
        item.product.id == product.id &&
        item.product.distributorId == product.distributorId &&
        item.product.selectedPackage == product.selectedPackage);
    final isProductInCart = orderItemInCart != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Theme.of(context).shadowColor.withAlpha(51),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _showProductDetailDialog(context, ref, product);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(77),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Center(child: ImageLoadingIndicator(size: 50)),
                      errorWidget: (context, url, error) => Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 24,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(102),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final favoritesMap = ref.watch(favoritesProvider);
                          final isFavorite = favoritesMap.containsKey(
                              '${product.id}_${product.distributorId}_${product.selectedPackage}');
                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.error,
                            ),
                            iconSize: 14,
                            onPressed: () {
                              ref
                                  .read(favoritesProvider.notifier)
                                  .toggleFavorite(product);
                              scaffoldMessengerKey.currentState?.showSnackBar(
                                SnackBar(
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.transparent,
                                  content: AwesomeSnackbarContent(
                                    title: isFavorite ? 'تم الحذف' : 'نجاح',
                                    message: isFavorite
                                        ? 'تمت إزالة ${product.name} من المفضلة'
                                        : 'addedToFavorites'
                                            .tr(args: [product.name]),
                                    contentType: isFavorite
                                        ? ContentType.failure
                                        : ContentType.success,
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isProductInCart
                            ? Colors.green.withAlpha(230)
                            : Theme.of(context).colorScheme.primary.withAlpha(230),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(isProductInCart ? Icons.check : Icons.add, color: Colors.white),
                        iconSize: 18,
                        onPressed: () {
                          if (isProductInCart) {
                            ref.read(orderProvider.notifier).removeProduct(orderItemInCart);
                          } else {
                            ref.read(orderProvider.notifier).addProduct(product);
                          }
                        },
                      ),
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.price?.toStringAsFixed(0) ?? 0} ${'LE'.tr()}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(153),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            distributorName,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(179),
                                  fontSize: 9,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (product.selectedPackage != null &&
                        product.selectedPackage!.isNotEmpty &&
                        product.selectedPackage!.length < 15)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.selectedPackage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
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
