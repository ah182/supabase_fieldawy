import 'dart:typed_data';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:fieldawy_store/widgets/invoice_preview_screen.dart';
import 'package:fieldawy_store/services/invoice_service.dart';

import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;
import 'package:collection/collection.dart';

import 'package:fieldawy_store/features/orders/application/orders_provider.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';

class DistributorOrderDetailsScreen extends HookConsumerWidget {
  final String distributorName;
  final List<OrderItemModel> products;

  const DistributorOrderDetailsScreen({
    super.key,
    required this.distributorName,
    required this.products,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orderState = ref.watch(orderProvider);
    final userDataAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    final animation = useMemoized(
        () => Tween(begin: -0.1, end: 0.1).animate(
              CurvedAnimation(
                parent: controller,
                curve: Curves.easeInOut,
              ),
            ),
        [controller]);

    useEffect(() {
      controller.repeat(reverse: true);
      return null; // Dispose is handled automatically by useAnimationController
    }, const []);

    // Find the distributor using UUID or name
    final distributor = distributorsAsync.whenOrNull(
      data: (distributors) => distributors.firstWhereOrNull(
        (d) => d.displayName == distributorName || (products.isNotEmpty && d.id == products.first.product.distributorUuid),
      ),
    );
    final whatsappNumber = distributor?.whatsappNumber;

    final currentProducts = orderState.where((item) {
      final product = item.product;
      // الفلترة بالـ UUID إذا توفر في أحد المنتجات الممرة
      final targetUuid = products.firstWhereOrNull((p) => p.product.distributorUuid != null)?.product.distributorUuid;
      if (targetUuid != null && product.distributorUuid == targetUuid) {
        return true;
      }
      // الفلترة بالاسم كخيار احتياطي
      return product.distributorId == distributorName;
    }).toList();

    final totalPrice = currentProducts.fold<double>(0.0, (sum, item) {
      final price = item.product.price ?? 0.0;
      return sum + (price * item.quantity);
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          distributorName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 16),
                        padding: const EdgeInsets.all(6),            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.shopping_bag_outlined,
                size: 16, color: theme.colorScheme.onPrimary),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.background,
      body: currentProducts.isEmpty
          ? Center(
              child: Text(
                'orders.no_products_distributor'.tr(),
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: currentProducts.length,
              itemBuilder: (context, index) {
          final orderItem = currentProducts[index];
          final product = orderItem.product;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (product.selectedPackage != null &&
                              product.selectedPackage!.isNotEmpty)
                            Text(
                              product.selectedPackage!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${NumberFormatter.formatCompact(product.price ?? 0)} ج',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref
                          .read(orderProvider.notifier)
                          .removeProduct(orderItem),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: orderItem.quantity > 1
                                ? () => ref
                                    .read(orderProvider.notifier)
                                    .decrementQuantity(orderItem)
                                : null,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: orderItem.quantity > 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.remove,
                                size: 14,
                                color: orderItem.quantity > 1
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.5),
                              ),
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 26,
                            alignment: Alignment.center,
                            child: Text(
                              orderItem.quantity.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ref
                                .read(orderProvider.notifier)
                                .incrementQuantity(orderItem),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(Icons.add,
                                  size: 14, color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'orders.create_invoice'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: RotationTransition(
                    turns: animation,
                    child: IconButton(
                      icon: Icon(Icons.receipt_long_outlined,
                          color: theme.colorScheme.primary, size: 28),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.picture_as_pdf),
                                title: Text('orders.save_pdf'.tr()),
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  try {
                                    final invoiceService = InvoiceService();
                                    final orderData = {
                                      'id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                                      'date': DateTime.now().toString(),
                                      'distributorName': distributorName,
                                      'products': currentProducts
                                          .map((item) => {
                                                'name': item.product.name,
                                                'quantity': item.quantity,
                                                'price':
                                                    item.product.price ?? 0.0,
                                                'selectedPackage': item
                                                    .product.selectedPackage,
                                              })
                                          .toList(),
                                      'total': totalPrice,
                                      'clientName': userDataAsync
                                              .value?.displayName ??
                                          'N/A', // Use the actual clientName
                                    };
                                    final pdfBytes = await invoiceService
                                        .createInvoice(orderData);
                                    await Printing.layoutPdf(
                                        onLayout: (format) => pdfBytes);
                                  } catch (e) {
                                    if (context.mounted) {
                                       final snackBar = SnackBar(
                                        elevation: 0,
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.transparent,
                                        content: AwesomeSnackbarContent(
                                          title: 'خطأ'.tr(),
                                          message: 'orders.pdf_error'.tr(namedArgs: {'error': e.toString()}),
                                          contentType: ContentType.failure,
                                        ),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                    }
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.image),
                                title: Text('orders.preview_invoice'.tr()),
                                onTap: () async {
                                  // First, close the modal bottom sheet.
                                  Navigator.of(ctx).pop();

                                  // Show a loading dialog.
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    },
                                  );

                                  PdfDocument? doc;
                                  try {
                                    final invoiceService = InvoiceService();
                                    final orderData = {
                                      'id': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                                      'date': DateTime.now().toString(),
                                      'distributorName': distributorName,
                                      'products': currentProducts
                                          .map((item) => {
                                                'name': item.product.name,
                                                'quantity': item.quantity,
                                                'price':
                                                    item.product.price ?? 0.0,
                                                'selectedPackage': item
                                                    .product.selectedPackage,
                                              })
                                          .toList(),
                                      'total': totalPrice,
                                      'clientName': userDataAsync
                                              .value?.displayName ??
                                          'N/A',
                                    };
                                    final pdfBytes = await invoiceService
                                        .createInvoice(orderData);

                                    // Open the PDF document
                                    doc = await PdfDocument.openData(pdfBytes);
                                    final dpr =
                                        MediaQuery.of(context).devicePixelRatio;
                                    final List<Uint8List> imageBytesList = [];

                                    // Loop through all pages and render them
                                    for (var i = 0; i < doc.pages.length; i++) {
                                      final page = doc.pages[i];
                                      final pageImage = await page.render(
                                        width: (page.width * dpr * 0.5).toInt(),
                                        height: (page.height * dpr * 0.5).toInt(),
                                      );
                                      if (pageImage != null) {
                                        final image = img.Image.fromBytes(
                                          width: pageImage.width,
                                          height: pageImage.height,
                                          bytes: pageImage.pixels.buffer,
                                          order: img.ChannelOrder.rgba,
                                        );
                                        imageBytesList.add(img.encodePng(image));
                                      }
                                    }

                                    if (imageBytesList.isNotEmpty) {
                                      // Pop the loading dialog before navigating.
                                      if (context.mounted) {
                                        Navigator.of(context, rootNavigator: true).pop();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                InvoicePreviewScreen(
                                              imageBytesList: imageBytesList,
                                              pdfBytes: pdfBytes,
                                              whatsappNumber: whatsappNumber,
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      // Pop the loading dialog if image generation fails.
                                      if (context.mounted) {
                                        Navigator.of(context, rootNavigator: true).pop();
                                        final snackBar = SnackBar(
                                          elevation: 0,
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.transparent,
                                          content: AwesomeSnackbarContent(
                                            title: 'خطأ'.tr(),
                                            message: 'orders.preview_generic_error'.tr(),
                                            contentType: ContentType.failure,
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                    }
                                  } catch (e) {
                                    // Pop the loading dialog on error.
                                    if (context.mounted) {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      final snackBar = SnackBar(
                                        elevation: 0,
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.transparent,
                                        content: AwesomeSnackbarContent(
                                          title: 'خطأ'.tr(),
                                          message: 'orders.preview_error'.tr(namedArgs: {'error': e.toString()}),
                                          contentType: ContentType.failure,
                                        ),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                    }
                                  } finally {
                                    await doc?.dispose();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  constraints: const BoxConstraints(maxWidth: 150),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${NumberFormatter.formatCompact(totalPrice)} EGP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}