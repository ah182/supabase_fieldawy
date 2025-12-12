import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';
import 'package:fieldawy_store/features/products/presentation/screens/my_products_screen.dart';

class RecentProductsWidget extends ConsumerWidget {
  const RecentProductsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentProductsAsync = ref.watch(recentProductsProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard_feature.recent_products.title'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to all products
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MyProductsScreen(),
                      ),
                    );
                  },
                  child: Text('dashboard_feature.recent_products.view_all'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recentProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'dashboard_feature.recent_products.no_products'.tr(),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const MyProductsScreen(),
                              ),
                            );
                          },
                          child: Text('dashboard_feature.recent_products.add_new'.tr()),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductItem(context, product);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  children: [
                    Text(
                      'dashboard_feature.recent_products.error_load'.tr(),
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // Fix: Use the refresh result properly
                        ref.invalidate(recentProductsProvider);
                      },
                      child: Text('dashboard_feature.recent_products.retry'.tr()),
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

  Widget _buildProductItem(BuildContext context, Map<String, dynamic> product) {
    final createdAt = DateTime.tryParse(product['created_at'] ?? '');
    final timeAgo = createdAt != null ? _getTimeAgo(createdAt) : '';
    final source = product['source'] ?? 'catalog';
    final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? '';
    final price = product['price'] ?? 0;
    final views = product['views'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MyProductsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getSourceColor(source).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getSourceColor(source).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _buildRecentProductImage(productId, source),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name + Source Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? 'dashboard_feature.recent_products.unknown_product'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF1a1a1a),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildCompactSourceBadge(source),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Price + Stats Row
                      Row(
                        children: [
                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$price ${'EGP'.tr()}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Views
                          _buildMiniStat(Icons.visibility_outlined, '$views', Colors.blue),
                          
                          const Spacer(),
                          
                          // Time Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 10, color: Colors.orange[700]),
                                const SizedBox(width: 3),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildRecentProductImage(String productId, String source) {
    return FutureBuilder<String?>(
      future: _getRecentProductImageFromDatabase(productId, source),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getSourceColor(source).withOpacity(0.7),
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildRecentPlaceholder(source);
            },
          );
        }
        
        return _buildRecentPlaceholder(source);
      },
    );
  }

  Widget _buildRecentPlaceholder(String source) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getSourceColor(source).withOpacity(0.2),
            _getSourceColor(source).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getSourceIcon(source),
          size: 20,
          color: _getSourceColor(source).withOpacity(0.7),
        ),
      ),
    );
  }

  Future<String?> _getRecentProductImageFromDatabase(String productId, String source) async {
    try {
      print('🖼️ Fetching recent product image for ID: $productId, Source: $source');
      
      if (productId.isEmpty) {
        print('⚠️ Product ID is empty');
        return null;
      }
      
      String? imageUrl;
      
      // محاولة جلب الصورة حسب نوع المصدر (نفس طريقة التوصيات)
      switch (source.toLowerCase()) {
        case 'catalog':
        case 'product':
        case 'products':
          try {
            // أولاً: محاولة البحث المباشر في products
            final response = await Supabase.instance.client
                .from('products')
                .select('image_url, name')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['image_url'] != null) {
              imageUrl = response.first['image_url']?.toString();
              print('✅ Found catalog product: ${response.first['name']}, Image: $imageUrl');
            } else {
              // ثانياً: محاولة البحث في distributor_products مع JOIN
              final distributorResponse = await Supabase.instance.client
                  .from('distributor_products')
                  .select('products!inner(image_url, name)')
                  .eq('id', productId)
                  .limit(1);
              
              if (distributorResponse.isNotEmpty && distributorResponse.first['products'] != null) {
                final product = distributorResponse.first['products'];
                imageUrl = product['image_url']?.toString();
                print('✅ Found distributor product: ${product['name']}, Image: $imageUrl');
              }
            }
          } catch (e) {
            print('❌ Error fetching from products: $e');
            // Fallback: محاولة استخراج UUID من المعرف المركب
            try {
              String actualProductId = productId;
              if (productId.contains('_')) {
                actualProductId = productId.split('_')[0];
                print('🔧 Extracted UUID: $actualProductId from: $productId');
              }
              
              final fallbackResponse = await Supabase.instance.client
                  .from('products')
                  .select('image_url, name')
                  .eq('id', actualProductId)
                  .limit(1);
              
              if (fallbackResponse.isNotEmpty && fallbackResponse.first['image_url'] != null) {
                imageUrl = fallbackResponse.first['image_url']?.toString();
                print('✅ Found product (UUID extraction): ${fallbackResponse.first['name']}, Image: $imageUrl');
              }
            } catch (fallbackError) {
              print('❌ Product fallback failed: $fallbackError');
            }
          }
          break;
          
        case 'surgical':
        case 'surgical_tool':
        case 'surgical_tools':
          try {
            // البحث في جدول distributor_surgical_tools مع join للجدول الرئيسي
            final response = await Supabase.instance.client
                .from('distributor_surgical_tools')
                .select('surgical_tools!inner(image_url, tool_name)')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['surgical_tools'] != null) {
              final surgicalTool = response.first['surgical_tools'];
              imageUrl = surgicalTool['image_url']?.toString();
              print('✅ Found surgical tool: ${surgicalTool['tool_name']}, Image: $imageUrl');
            }
          } catch (e) {
            print('❌ Error fetching from distributor_surgical_tools: $e');
            // Fallback: محاولة البحث المباشر في surgical_tools
            try {
              final fallbackResponse = await Supabase.instance.client
                  .from('surgical_tools')
                  .select('image_url, tool_name')
                  .eq('id', productId)
                  .limit(1);
              
              if (fallbackResponse.isNotEmpty && fallbackResponse.first['image_url'] != null) {
                imageUrl = fallbackResponse.first['image_url']?.toString();
                print('✅ Found surgical tool (fallback): ${fallbackResponse.first['tool_name']}, Image: $imageUrl');
              }
            } catch (fallbackError) {
              print('❌ Fallback also failed: $fallbackError');
            }
          }
          break;
          
        case 'ocr':
        case 'ocr_product':
        case 'ocr_products':
          try {
            final response = await Supabase.instance.client
                .from('ocr_products')
                .select('image_url, product_name')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['image_url'] != null) {
              imageUrl = response.first['image_url']?.toString();
              print('✅ Found OCR product: ${response.first['product_name']}, Image: $imageUrl');
            }
          } catch (e) {
            print('❌ Error fetching from ocr_products: $e');
          }
          break;
          
        default:
          print('🔍 Unknown source, trying all tables...');
          // البحث المتدرج في جميع الجداول
          
          // 1. محاولة المنتجات العادية
          try {
            final productsResponse = await Supabase.instance.client
                .from('products')
                .select('image_url, name')
                .eq('id', productId)
                .limit(1);
            
            if (productsResponse.isNotEmpty && productsResponse.first['image_url'] != null) {
              imageUrl = productsResponse.first['image_url'].toString();
              print('✅ Found in products table: ${productsResponse.first['name']}');
            } else {
              // محاولة distributor_products
              final distributorResponse = await Supabase.instance.client
                  .from('distributor_products')
                  .select('products!inner(image_url, name)')
                  .eq('id', productId)
                  .limit(1);
              
              if (distributorResponse.isNotEmpty && distributorResponse.first['products'] != null) {
                final product = distributorResponse.first['products'];
                imageUrl = product['image_url']?.toString();
                print('✅ Found in distributor_products table: ${product['name']}');
              } else {
                // محاولة استخراج UUID
                String actualProductId = productId;
                if (productId.contains('_')) {
                  actualProductId = productId.split('_')[0];
                  print('🔧 Fallback: Extracted UUID $actualProductId from: $productId');
                  
                  final uuidResponse = await Supabase.instance.client
                      .from('products')
                      .select('image_url, name')
                      .eq('id', actualProductId)
                      .limit(1);
                  
                  if (uuidResponse.isNotEmpty && uuidResponse.first['image_url'] != null) {
                    imageUrl = uuidResponse.first['image_url'].toString();
                    print('✅ Found in products table (UUID): ${uuidResponse.first['name']}');
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Products fallback failed: $e');
          }
          
          // 2. الأدوات الجراحية
          if (imageUrl == null) {
            try {
              final toolsResponse = await Supabase.instance.client
                  .from('distributor_surgical_tools')
                  .select('surgical_tools!inner(image_url, tool_name)')
                  .eq('id', productId)
                  .limit(1);
              
              if (toolsResponse.isNotEmpty && toolsResponse.first['surgical_tools'] != null) {
                final surgicalTool = toolsResponse.first['surgical_tools'];
                imageUrl = surgicalTool['image_url'].toString();
                print('✅ Found in distributor_surgical_tools table: ${surgicalTool['tool_name']}');
              }
            } catch (e) {
              print('❌ Distributor surgical tools fallback failed: $e');
              // Fallback للجدول الرئيسي
              try {
                final directResponse = await Supabase.instance.client
                    .from('surgical_tools')
                    .select('image_url, tool_name')
                    .eq('id', productId)
                    .limit(1);
                
                if (directResponse.isNotEmpty && directResponse.first['image_url'] != null) {
                  imageUrl = directResponse.first['image_url'].toString();
                  print('✅ Found in surgical_tools table (direct): ${directResponse.first['tool_name']}');
                }
              } catch (directError) {
                print('❌ Direct surgical tools fallback failed: $directError');
              }
            }
          }
          
          // 3. منتجات OCR
          if (imageUrl == null) {
            try {
              final ocrResponse = await Supabase.instance.client
                  .from('ocr_products')
                  .select('image_url, product_name')
                  .eq('id', productId)
                  .limit(1);
              
              if (ocrResponse.isNotEmpty && ocrResponse.first['image_url'] != null) {
                imageUrl = ocrResponse.first['image_url'].toString();
                print('✅ Found in ocr_products table: ${ocrResponse.first['product_name']}');
              }
            } catch (e) {
              print('❌ OCR products fallback failed: $e');
            }
          }
          break;
      }
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        print('🎉 Final recent image URL: $imageUrl');
        return imageUrl;
      } else {
        print('⚠️ No image found for recent product $productId');
        return null;
      }
      
    } catch (e) {
      print('❌ Error fetching recent product image: $e');
      return null;
    }
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSourceBadge(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _getSourceColor(source).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getSourceColor(source).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getSourceIcon(source), size: 10, color: _getSourceColor(source)),
          const SizedBox(width: 3),
          Text(
            _getSourceLabel(source),
            style: TextStyle(
              color: _getSourceColor(source),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ), 
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'offer': return Colors.red;
      case 'course': return Colors.purple;
      case 'book': return Colors.brown;
      case 'surgical': return Colors.teal;
      case 'ocr': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'offer': return Icons.local_offer;
      case 'course': return Icons.school;
      case 'book': return Icons.menu_book;
      case 'surgical': return Icons.medical_services;
      case 'ocr': return Icons.qr_code_scanner;
      default: return Icons.inventory;
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'offer': return 'dashboard_feature.recent_products.source.offer'.tr();
      case 'course': return 'dashboard_feature.recent_products.source.course'.tr();
      case 'book': return 'dashboard_feature.recent_products.source.book'.tr();
      case 'surgical': return 'dashboard_feature.recent_products.source.surgical'.tr();
      case 'ocr': return 'dashboard_feature.recent_products.source.ocr'.tr();
      default: return 'dashboard_feature.recent_products.source.product'.tr();
    }
  }


  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'dashboard_feature.recent_products.time.day'.tr(namedArgs: {'count': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return 'dashboard_feature.recent_products.time.hour'.tr(namedArgs: {'count': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return 'dashboard_feature.recent_products.time.min'.tr(namedArgs: {'count': difference.inMinutes.toString()});
    } else {
      return 'dashboard_feature.recent_products.time.now'.tr();
    }
  }
}