import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/stories/utils/story_product_helper.dart';
import 'package:flutter/material.dart';

class ProductTagOverlay extends StatefulWidget {
  final String productLinkId;
  final VoidCallback? onDialogOpened;
  final VoidCallback? onDialogClosed;

  const ProductTagOverlay({
    super.key,
    required this.productLinkId,
    this.onDialogOpened,
    this.onDialogClosed,
  });

  @override
  State<ProductTagOverlay> createState() => ProductTagOverlayState();
}

class ProductTagOverlayState extends State<ProductTagOverlay> {
  Future<Map<String, dynamic>?>? _productFuture;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  void _fetchProductDetails() {
    _productFuture = StoryProductHelper.fetchProductDetails(widget.productLinkId);
  }

  Future<void> showDetails() async {
    if (_data == null) return;
    
    widget.onDialogOpened?.call();
    await StoryProductHelper.openProductDialog(context, _data!);
    widget.onDialogClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        _data = snapshot.data!;
        final data = _data!;
        
        String name = 'Unknown';
        String? imageUrl;
        String? priceText;
        final type = data['type'];
        
        switch (type) {
          case 'regular':
            final p = data['products'] as Map<String, dynamic>;
            name = p['name'] ?? 'Unknown';
            imageUrl = p['image_url'];
            priceText = '${data['price']} EGP';
            break;
          case 'ocr':
            final p = data['ocr_products'] as Map<String, dynamic>;
            name = p['product_name'] ?? 'Unknown';
            imageUrl = p['image_url'];
            priceText = '${data['price']} EGP';
            break;
          case 'tool':
            name = data['tool_name'] ?? 'Surgical Tool';
            imageUrl = data['image_url'];
            priceText = data['price'] != null ? '${data['price']} EGP' : null;
            break;
          case 'supply':
            name = data['name'] ?? 'Supply';
            imageUrl = data['image_url'];
            priceText = data['price'] != null ? '${data['price']} EGP' : null;
            break;
          case 'book':
            name = data['title'] ?? 'Book';
            imageUrl = data['image_url'] ?? data['cover_url'];
            priceText = data['price'] != null ? '${data['price']} EGP' : null;
            break;
          case 'course':
            name = data['title'] ?? 'Course';
            imageUrl = data['image_url'] ?? data['poster_url'];
            priceText = data['price'] != null ? '${data['price']} EGP' : null;
            break;
          case 'offer':
            name = data['title'] ?? 'Offer';
            imageUrl = data['image_url'];
            priceText = data['price'] != null ? '${data['price']} EGP' : null;
            break;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceText ?? 'Ask for price',
                      style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'book' || type == 'course' ? Icons.arrow_forward_ios_rounded : Icons.shopping_bag_outlined,
                  color: Colors.indigo,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
