import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/application/favorites_provider.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/main.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// Set لتتبع المنتجات التي تم حساب مشاهداتها لتجنب التكرار
final Set<String> _viewedProducts = {};

// Helper function to check if a string is a valid UUID
bool _isValidUUID(String id) {
  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  );
  return uuidRegex.hasMatch(id);
}

// دالة لتنسيق عدد المشاهدات بشكل مختصر
String _formatViewsCount(int views) {
  if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M';
  } else if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K';
  } else {
    return views.toString();
  }
}

// دالة مساعدة لزيادة مشاهدات المنتج (Regular, OCR, Surgical, Offers)
// تستخدم النظام الجديد الذي يسجل في product_views
void _incrementProductViews(String productId, {String? distributorId, String? productType}) {
  try {
    print('🔵 [_incrementProductViews] ========== START ==========');
    print('🔵 [_incrementProductViews] Product ID: $productId');
    print('🔵 [_incrementProductViews] Product Type: $productType');
    print('🔵 [_incrementProductViews] Distributor ID: $distributorId');

    // تحديد نوع المنتج
    String type = 'regular';

    if (productType == 'offers') {
      type = 'offer';
      print('🔵 [_incrementProductViews] Detected as OFFER');
    } else if (productType == 'surgical') {
      type = 'surgical';
      print('🔵 [_incrementProductViews] Detected as SURGICAL');
    } else if (productType == 'ocr') {
      type = 'ocr';
      print('🔵 [_incrementProductViews] Detected as OCR');
    } else {
      print('🔵 [_incrementProductViews] Checking if UUID...');
      // تحقق من صيغة الـ ID
      if (_isValidUUID(productId)) {
        print('🔵 [_incrementProductViews] Is UUID - checking if OCR...');
        // قد يكون OCR، نحتاج للتحقق
        Supabase.instance.client
            .from('distributor_ocr_products')
            .select('id')
            .eq('ocr_product_id', productId)
            .limit(1)
            .then((ocrResponse) {
          if (ocrResponse.isNotEmpty) {
            print('🔵 [_incrementProductViews] Confirmed as OCR product');
            _trackView(productId, 'ocr');
          } else {
            print('🔵 [_incrementProductViews] Not OCR - treating as REGULAR');
            _trackView(productId, 'regular');
          }
        }).catchError((error) {
          print('❌ [_incrementProductViews] Error checking OCR: $error');
          print('🔵 [_incrementProductViews] Fallback to REGULAR');
          _trackView(productId, 'regular');
        });
        return; // الخروج لأننا سنتابع في then
      } else {
        print('🔵 [_incrementProductViews] Not UUID - treating as REGULAR');
      }
    }

    // تسجيل المشاهدة
    print('🔵 [_incrementProductViews] Final type: $type');
    print('🔵 [_incrementProductViews] Calling _trackView...');
    _trackView(productId, type);
    print('🔵 [_incrementProductViews] ========== END ==========');

  } catch (e) {
    print('❌ [_incrementProductViews] EXCEPTION: $e');
    print('❌ [_incrementProductViews] Stack trace: ${StackTrace.current}');
  }
}

// دالة مساعدة لتسجيل المشاهدة
Future<void> _trackView(String productId, String productType) async {
  print('🟢 [_trackView] Starting to track view...');
  print('🟢 [_trackView] Product ID: $productId');
  print('🟢 [_trackView] Product Type: $productType');

  try {
    final response = await Supabase.instance.client.rpc('track_product_view', params: {
      'p_product_id': productId,
      'p_product_type': productType,
    });

    print('✅ [_trackView] View tracked successfully!');
    print('✅ [_trackView] Product: $productId');
    print('✅ [_trackView] Type: $productType');
    print('✅ [_trackView] Response: $response');
  } catch (error) {
    print('❌ [_trackView] Error tracking view!');
    print('❌ [_trackView] Product: $productId');
    print('❌ [_trackView] Type: $productType');
    print('❌ [_trackView] Error: $error');
    print('❌ [_trackView] Error Type: ${error.runtimeType}');
  }
}

/// Widget wrapper يضيف تتبع المشاهدات للمنتجات
class ViewTrackingProductCard extends ConsumerStatefulWidget {
  const ViewTrackingProductCard({
    super.key,
    required this.product,
    required this.searchQuery,
    required this.onTap,
    this.showPriceChange = false,
    this.overlayBadge,
    this.statusBadge,
    this.productType = 'home',
    this.expirationDate,
    this.status,
    this.trackViewOnVisible = false, // تفعيل تتبع المشاهدة عند الظهور
  });

  final ProductModel product;
  final String searchQuery;
  final VoidCallback onTap;
  final bool showPriceChange;
  final Widget? overlayBadge;
  final Widget? statusBadge;
  final String productType;
  final DateTime? expirationDate;
  final String? status;
  final bool trackViewOnVisible;

  @override
  ConsumerState<ViewTrackingProductCard> createState() => _ViewTrackingProductCardState();
}

class _ViewTrackingProductCardState extends ConsumerState<ViewTrackingProductCard> {
  bool _hasBeenViewed = false;

  void _trackView() {
    if (_hasBeenViewed) return;
    
    final productKey = '${widget.product.id}_${widget.productType}';
    if (_viewedProducts.contains(productKey)) return;
    
    _hasBeenViewed = true;
    _viewedProducts.add(productKey);
    
    // زيادة المشاهدات (دعم Regular, OCR, و Surgical products)
    _incrementProductViews(
      widget.product.id,
      distributorId: widget.product.distributorId,
      productType: widget.productType,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.trackViewOnVisible) {
      // إذا لم يكن التتبع التلقائي مفعلاً، أرجع ProductCard عادي
      return ProductCard(
        product: widget.product,
        searchQuery: widget.searchQuery,
        onTap: widget.onTap,
        showPriceChange: widget.showPriceChange,
        overlayBadge: widget.overlayBadge,
        statusBadge: widget.statusBadge,
        productType: widget.productType,
        expirationDate: widget.expirationDate,
        status: widget.status,
      );
    }

    // استخدام VisibilityDetector لتتبع المشاهدة عند الظهور
    return VisibilityDetector(
      key: Key('product_${widget.product.id}_${widget.productType}'),
      onVisibilityChanged: (info) {
        // عندما يكون المنتج ظاهر بنسبة 50% أو أكثر
        if (info.visibleFraction >= 0.5 && !_hasBeenViewed) {
          _trackView();
        }
      },
      child: ProductCard(
        product: widget.product,
        searchQuery: widget.searchQuery,
        onTap: widget.onTap,
        showPriceChange: widget.showPriceChange,
        overlayBadge: widget.overlayBadge,
        statusBadge: widget.statusBadge,
        productType: widget.productType,
        expirationDate: widget.expirationDate,
        status: widget.status,
      ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.searchQuery,
    required this.onTap,
    this.showPriceChange = false,
    this.overlayBadge,
    this.statusBadge,
    this.productType = 'home',
    this.expirationDate,
    this.status,
  });

  final ProductModel product;
  final String searchQuery;
  final VoidCallback onTap;
  final bool showPriceChange;
  final Widget? overlayBadge;
  final Widget? statusBadge;
  final String productType; // 'home', 'expire_soon', 'surgical', 'offers', 'price_action'
  final DateTime? expirationDate;
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesMap = ref.watch(favoritesProvider);
    final isFavorite = favoritesMap.containsKey(
        '${product.id}_${product.distributorId}_${product.selectedPackage}');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === صورة المنتج مع أيقونة المفضلة ===
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
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
                              .withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  // === أيقونة المفضلة ===
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite
                              ? Colors.red
                              : Theme.of(context).colorScheme.error,
                        ),
                        iconSize: 14,
                        onPressed: () {
                          ref
                              .read(favoritesProvider.notifier)
                              .toggleFavorite(
                                product,
                                type: productType,
                                expirationDate: expirationDate,
                                status: status,
                                showPriceChange: showPriceChange,
                              );
                          scaffoldMessengerKey.currentState?.showSnackBar(
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
                    ),
                  ),
                  // === مؤشر نتائج البحث ===
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
                  // === Badge إضافي (مثل تاريخ الصلاحية) ===
                  if (overlayBadge != null) overlayBadge!,
                ],
              ),
            ),

            // === معلومات المنتج ===
            Flexible(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // === اسم المنتج ===
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

                    // === السعر مع عداد المشاهدات ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // === السعر ===
                        Flexible(
                          child: showPriceChange &&
                                  product.oldPrice != null &&
                                  product.price != null &&
                                  product.oldPrice != 0 &&
                                  product.oldPrice != product.price
                              ? Wrap(
                                  spacing: 4.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Old Price Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ' ${product.oldPrice?.toStringAsFixed(0) ?? ''} ${'LE'.tr()}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    // New Price Badge
                                    _PriceChangeBadge(
                                      oldPrice: product.oldPrice!,
                                      newPrice: product.price!,
                                    ),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${product.price?.toStringAsFixed(0) ?? '0'} ${'LE'.tr()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                        ),
                        
                        // === عداد المشاهدات مع Badge احترافي ===
                        if (product.views > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                  Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.visibility,
                                    size: 8,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatViewsCount(product.views),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // === اسم الموزع ===
                    Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            product.distributorId ?? 'موزع غير معروف',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  fontSize: 9,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // === Badge الحالة (للأدوات الجراحية) ===
                    if (statusBadge != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: statusBadge!,
                      ),

                    // === حجم العبوة ===
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

class _PriceChangeBadge extends StatelessWidget {
  const _PriceChangeBadge({
    required this.oldPrice,
    required this.newPrice,
  });

  final double oldPrice;
  final double newPrice;

  @override
  Widget build(BuildContext context) {
    final bool priceIncreased = newPrice > oldPrice;
    final Color solidBadgeColor = priceIncreased ? Colors.green : Colors.red;
    final IconData arrowIcon =
        priceIncreased ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: solidBadgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            arrowIcon,
            color: solidBadgeColor,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            '${newPrice.toStringAsFixed(0)} ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: solidBadgeColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}