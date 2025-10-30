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

// دالة مساعدة لزيادة مشاهدات المنتج (Regular, OCR, Surgical)
void _incrementProductViews(String productId, {String? distributorId, String? productType}) {
  try {
    print('🔵 Incrementing views for product: $productId, type: $productType, distributorId: $distributorId');
    
    // تحقق من نوع المنتج
    if (productType == 'surgical') {
      // أداة جراحية
      Supabase.instance.client.rpc('increment_surgical_tool_views', params: {
        'p_tool_id': productId,
      }).then((response) {
        print('✅ Surgical tool views incremented successfully');
      }).catchError((error) {
        print('❌ Error incrementing surgical tool views: $error');
      });
    } else {
      // تحقق من صيغة الـ ID - إذا كان integer/text، اعتبره منتج عادي
      if (!_isValidUUID(productId)) {
        // هذا منتج عادي (ID = integer/text)
        print('🔍 This is a regular product with integer ID: $productId');
        
        Supabase.instance.client.rpc('increment_product_views', params: {
          'p_product_id': productId,
        }).then((response) {
          print('✅ Regular product views incremented successfully for ID: $productId');
        }).catchError((error) {
          print('❌ Error incrementing regular product views: $error');
        });
      } else {
        // ID هو UUID - تحقق من نوع المنتج (OCR أم عادي)
        print('🔍 UUID format detected, checking if OCR product: $productId');
        
        Supabase.instance.client
            .from('distributor_ocr_products')
            .select('distributor_id')
            .eq('ocr_product_id', productId)
            .limit(1)
            .then((ocrResponse) {
          
          if (ocrResponse.isNotEmpty) {
            // هذا منتج OCR - استخدم أول موزع في القائمة
            final ocrDistributorId = ocrResponse[0]['distributor_id'] as String;
            print('🔍 Found OCR product with distributor_id: $ocrDistributorId');
            
            Supabase.instance.client.rpc('increment_ocr_product_views', params: {
              'p_distributor_id': ocrDistributorId,
              'p_ocr_product_id': productId,
            }).then((response) {
              print('✅ OCR product views incremented successfully for product: $productId');
            }).catchError((error) {
              print('❌ Error incrementing OCR product views: $error');
            });
          } else {
            // هذا منتج عادي من الكتالوج (UUID format)
            print('🔍 This is a regular catalog product with UUID: $productId');
            
            Supabase.instance.client.rpc('increment_product_views', params: {
              'p_product_id': productId,
            }).then((response) {
              print('✅ Regular product views incremented successfully for ID: $productId');
            }).catchError((error) {
              print('❌ Error incrementing regular product views: $error');
            });
          }
        }).catchError((error) {
          print('❌ Error checking product type: $error');
          // في حالة الخطأ، افترض أنه منتج عادي
          Supabase.instance.client.rpc('increment_product_views', params: {
            'p_product_id': productId,
          }).then((response) {
            print('✅ Regular product views incremented successfully (fallback) for ID: $productId');
          }).catchError((fallbackError) {
            print('❌ Error incrementing regular product views (fallback): $fallbackError');
          });
        });
      }
    }
  } catch (e) {
    print('❌ خطأ في زيادة مشاهدات المنتج: $e');
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
                    
                    // === عداد المشاهدات ===
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 10,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${product.views} ${product.views == 1 ? 'مشاهدة' : 'مشاهدات'}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                    ),

                    // === السعر ===
                    if (showPriceChange &&
                        product.oldPrice != null &&
                        product.price != null &&
                        product.oldPrice != 0 &&
                        product.oldPrice != product.price)
                      Wrap(
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
                    else
                      // Default price display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
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