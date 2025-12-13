import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';

class TopProductsWidget extends ConsumerWidget {
  const TopProductsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topProductsAsync = ref.watch(topProductsProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  'أفضل المنتجات أداءً',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            topProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد بيانات أداء',
                          style: TextStyle(color: Colors.grey[600]),
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
                    return _buildTopProductItem(context, product, index + 1);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'خطأ في تحميل البيانات',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductItem(BuildContext context, Map<String, dynamic> product, int rank) {
    final views = product['views'] ?? 0;
    final price = product['price'] ?? 0;
    final source = product['source'] ?? 'catalog';
    final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? '';

    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey[400]!;
        rankIcon = Icons.workspace_premium;
        break;
      case 3:
        rankColor = Colors.orange[300]!;
        rankIcon = Icons.military_tech;
        break;
      default:
        rankColor = Colors.blue;
        rankIcon = Icons.trending_up;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to product details
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Rank Badge + Product Image
                Stack(
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
                        child: _buildTopProductImage(productId, source),
                      ),
                    ),
                    // Rank Badge Overlay
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: rankColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: rankColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: rank <= 3 
                            ? Icon(rankIcon, size: 10, color: Colors.white)
                            : Text(
                                '$rank',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
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
                              product['name'] ?? 'منتج غير معروف',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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
                      
                      // Performance Stats Row
                      Row(
                        children: [
                          // Views Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, size: 10, color: Colors.green[700]),
                                const SizedBox(width: 3),
                                Text(
                                  NumberFormatter.formatCompact(views),
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Price Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${NumberFormatter.formatCompact(price)} ${'EGP'.tr()}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Performance Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rankColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, size: 10, color: rankColor),
                                const SizedBox(width: 3),
                                Text(
                                  _getPerformanceLabel(rank),
                                  style: TextStyle(
                                    color: rankColor,
                                    fontSize: 9,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductImage(String productId, String source) {
    return FutureBuilder<String?>(
      future: _getTopProductImageFromDatabase(productId, source),
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
              return _buildTopPlaceholder(source);
            },
          );
        }
        
        return _buildTopPlaceholder(source);
      },
    );
  }

  Widget _buildTopPlaceholder(String source) {
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

  Future<String?> _getTopProductImageFromDatabase(String productId, String source) async {
    try {
      print('🏆 Fetching top product image for ID: $productId, Source: $source');
      
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
              print('✅ Found top catalog product: ${response.first['name']}, Image: $imageUrl');
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
                print('✅ Found top distributor product: ${product['name']}, Image: $imageUrl');
              }
            }
          } catch (e) {
            print('❌ Error fetching from products: $e');
            // Fallback: محاولة استخراج UUID من المعرف المركب
            try {
              String actualProductId = productId;
              if (productId.contains('_')) {
                actualProductId = productId.split('_')[0];
                print('🔧 Extracted top UUID: $actualProductId from: $productId');
              }
              
              final fallbackResponse = await Supabase.instance.client
                  .from('products')
                  .select('image_url, name')
                  .eq('id', actualProductId)
                  .limit(1);
              
              if (fallbackResponse.isNotEmpty && fallbackResponse.first['image_url'] != null) {
                imageUrl = fallbackResponse.first['image_url']?.toString();
                print('✅ Found top product (UUID extraction): ${fallbackResponse.first['name']}, Image: $imageUrl');
              }
            } catch (fallbackError) {
              print('❌ Top product fallback failed: $fallbackError');
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
              print('✅ Found top surgical tool: ${surgicalTool['tool_name']}, Image: $imageUrl');
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
                print('✅ Found top surgical tool (fallback): ${fallbackResponse.first['tool_name']}, Image: $imageUrl');
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
            // محاولة البحث في distributor_ocr_products مع JOIN
            final response = await Supabase.instance.client
                .from('distributor_ocr_products')
                .select('ocr_products!inner(image_url, product_name)')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['ocr_products'] != null) {
              final data = response.first['ocr_products'];
              Map<String, dynamic>? ocrProduct;
              
              if (data is List && data.isNotEmpty) {
                ocrProduct = data.first as Map<String, dynamic>;
              } else if (data is Map) {
                ocrProduct = data as Map<String, dynamic>;
              }

              if (ocrProduct != null) {
                imageUrl = ocrProduct['image_url']?.toString();
                print('✅ Found top OCR product: ${ocrProduct['product_name']}, Image: $imageUrl');
              }
            }
          } catch (e) {
            print('❌ Error fetching from distributor_ocr_products: $e');
            // Fallback: البحث المباشر إذا كان الآيدي هو آيدي المنتج نفسه
            try {
              final directResponse = await Supabase.instance.client
                  .from('ocr_products')
                  .select('image_url, product_name')
                  .eq('id', productId)
                  .limit(1);
              if (directResponse.isNotEmpty && directResponse.first['image_url'] != null) {
                imageUrl = directResponse.first['image_url']?.toString();
              }
            } catch (_) {}
          }
          break;
          
        case 'offer':
        case 'offers':
          try {
            // أولاً: جلب تفاصيل العرض لمعرفة المنتج المرتبط
            final offerResponse = await Supabase.instance.client
                .from('offers')
                .select('product_id, is_ocr')
                .eq('id', productId)
                .limit(1);

            if (offerResponse.isNotEmpty) {
              final offer = offerResponse.first;
              
              // نبحث عن صورة المنتج المرتبط
              if (offer['product_id'] != null) {
                final isOcr = offer['is_ocr'] == true;
                final linkedProductId = offer['product_id'];
                
                if (isOcr) {
                   // البحث في ocr_products
                   final productResponse = await Supabase.instance.client
                      .from('ocr_products')
                      .select('image_url')
                      .eq('ocr_product_id', linkedProductId)
                      .maybeSingle();
                   
                   if (productResponse != null) {
                     imageUrl = productResponse['image_url']?.toString();
                   } else {
                     // Fallback: Try with 'id' just in case
                     final fallbackResponse = await Supabase.instance.client
                        .from('ocr_products')
                        .select('image_url')
                        .eq('id', linkedProductId)
                        .maybeSingle();
                     if (fallbackResponse != null) {
                       imageUrl = fallbackResponse['image_url']?.toString();
                     }
                   }
                } else {
                   final productResponse = await Supabase.instance.client
                      .from('products')
                      .select('image_url')
                      .eq('id', linkedProductId)
                      .maybeSingle();
                   
                   if (productResponse != null) {
                     imageUrl = productResponse['image_url']?.toString();
                   }
                }
                print('✅ Found top offer linked product image: $imageUrl');
              }
            }
          } catch (e) {
            print('❌ Error fetching from offers: $e');
          }
          break;
          
        case 'course':
        case 'courses':
          try {
            final response = await Supabase.instance.client
                .from('vet_courses')
                .select('image_url, title')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['image_url'] != null) {
              imageUrl = response.first['image_url']?.toString();
              print('✅ Found top course: ${response.first['title']}, Image: $imageUrl');
            }
          } catch (e) {
            print('❌ Error fetching from courses: $e');
          }
          break;
          
        case 'book':
        case 'books':
          try {
            final response = await Supabase.instance.client
                .from('vet_books')
                .select('image_url, name')
                .eq('id', productId)
                .limit(1);
            
            if (response.isNotEmpty && response.first['image_url'] != null) {
              imageUrl = response.first['image_url']?.toString();
              print('✅ Found top book: ${response.first['name']}, Image: $imageUrl');
            }
          } catch (e) {
            print('❌ Error fetching from books: $e');
          }
          break;
          
        default:
          print('🔍 Unknown source, trying all tables for top products...');
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
                print('✅ Found in top distributor_products table: ${product['name']}');
              } else {
                // محاولة استخراج UUID
                String actualProductId = productId;
                if (productId.contains('_')) {
                  actualProductId = productId.split('_')[0];
                  print('🔧 Top fallback: Extracted UUID $actualProductId from: $productId');
                  
                  final uuidResponse = await Supabase.instance.client
                      .from('products')
                      .select('image_url, name')
                      .eq('id', actualProductId)
                      .limit(1);
                  
                  if (uuidResponse.isNotEmpty && uuidResponse.first['image_url'] != null) {
                    imageUrl = uuidResponse.first['image_url'].toString();
                    print('✅ Found in top products table (UUID): ${uuidResponse.first['name']}');
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Top products fallback failed: $e');
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
          
          // 3. العروض
          if (imageUrl == null) {
            try {
              final offersResponse = await Supabase.instance.client
                  .from('offers')
                  .select('product_id, is_ocr')
                  .eq('id', productId)
                  .limit(1);
              
              if (offersResponse.isNotEmpty) {
                final offer = offersResponse.first;
                if (offer['product_id'] != null) {
                  final linkedId = offer['product_id'];
                  final isOcr = offer['is_ocr'] == true;
                  
                  if (isOcr) {
                     final ocrResp = await Supabase.instance.client
                        .from('ocr_products')
                        .select('image_url')
                        .eq('ocr_product_id', linkedId)
                        .maybeSingle();
                     imageUrl = ocrResp?['image_url']?.toString();
                  } else {
                     final prodResp = await Supabase.instance.client
                        .from('products')
                        .select('image_url')
                        .eq('id', linkedId)
                        .maybeSingle();
                     imageUrl = prodResp?['image_url']?.toString();
                  }
                  print('✅ Found in offers table (via linked product): $imageUrl');
                }
              }
            } catch (e) {
              print('❌ Offers fallback failed: $e');
            }
          }
          
          // 4. الكورسات
          if (imageUrl == null) {
            try {
              final coursesResponse = await Supabase.instance.client
                  .from('vet_courses')
                  .select('image_url, title')
                  .eq('id', productId)
                  .limit(1);
              
              if (coursesResponse.isNotEmpty && coursesResponse.first['image_url'] != null) {
                imageUrl = coursesResponse.first['image_url'].toString();
                print('✅ Found in courses table: ${coursesResponse.first['title']}');
              }
            } catch (e) {
              print('❌ Courses fallback failed: $e');
            }
          }
          
          // 5. الكتب
          if (imageUrl == null) {
            try {
              final booksResponse = await Supabase.instance.client
                  .from('vet_books')
                  .select('image_url, name')
                  .eq('id', productId)
                  .limit(1);
              
              if (booksResponse.isNotEmpty && booksResponse.first['image_url'] != null) {
                imageUrl = booksResponse.first['image_url'].toString();
                print('✅ Found in books table: ${booksResponse.first['name']}');
              }
            } catch (e) {
              print('❌ Books fallback failed: $e');
            }
          }
          
          // 6. منتجات OCR
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
        print('🎉 Final top product image URL: $imageUrl');
        return imageUrl;
      } else {
        print('⚠️ No image found for top product $productId');
        return null;
      }
      
    } catch (e) {
      print('❌ Error fetching top product image: $e');
      return null;
    }
  }

  Widget _buildCompactSourceBadge(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: _getSourceColor(source).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getSourceColor(source).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getSourceIcon(source), size: 8, color: _getSourceColor(source)),
          const SizedBox(width: 2),
          Text(
            _getSourceLabel(source),
            style: TextStyle(
              color: _getSourceColor(source),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getPerformanceLabel(int rank) {
    switch (rank) {
      case 1: return 'الأول';
      case 2: return 'الثاني';
      case 3: return 'الثالث';
      default: return 'متميز';
    }
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
      case 'offer': return 'عرض';
      case 'course': return 'كورس';
      case 'book': return 'كتاب';
      case 'surgical': return 'جراحي';
      case 'ocr': return 'OCR';
      default: return 'منتج';
    }
  }

}