import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';

class SmartRecommendationsWidget extends ConsumerWidget {
  const SmartRecommendationsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استخدام النظام الجديد المبني على المشاهدات والبحث
    final recommendationsAsync = ref.watch(smartRecommendationsProvider);

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lightbulb, color: Colors.purple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 توصيات ذكية',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'منتجات رائجة عالمياً - أضفها لكتالوجك',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Text(
                    'مُخصص لك',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recommendationsAsync.when(
              data: (products) {
                print('🔍 Smart recommendations data received: $products');
                
                // البيانات الآن تأتي مباشرة من النظام الجديد
                List<Map<String, dynamic>> recommendations = products;
                
                print('📊 Smart recommendations count: ${recommendations.length}');
                if (recommendations.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.purple[300]),
                        const SizedBox(height: 12),
                        Text(
                          'رائع! لديك جميع المنتجات الرائجة',
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'كتالوجك محدث بأحدث المنتجات',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recommendations.length > 5 ? 5 : recommendations.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final recommendation = recommendations[index];
                    return _buildRecommendationItem(context, recommendation, index + 1);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'خطأ في تحميل التوصيات',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(BuildContext context, Map<String, dynamic> recommendation, int rank) {
    print('🔨 Building recommendation item: $recommendation');
    
    // استخراج البيانات مع التحقق من أسماء الحقول المختلفة
    final productName = recommendation['name'] ?? 
                       recommendation['product_name'] ?? 
                       recommendation['tool_name'] ?? 
                       'منتج غير معروف';
    
    final reason = recommendation['reason'] ?? 
                  'منتج مشهور - ${recommendation['distributor_count'] ?? 0} موزع';
    
    final badge = recommendation['badge'] ?? 
                 (recommendation['distributor_count'] != null && recommendation['distributor_count'] > 3 ? 'مشهور' : 'مميز');
    
    final productType = recommendation['type'] ?? 'catalog_product';
    final category = recommendation['category'] ?? 'trending';
    final productId = recommendation['id']?.toString() ?? '';
    final views = recommendation['views'] ?? 0;
    final distributorCount = recommendation['distributor_count'] ?? 0;
    
    print('🏷️ Product name: $productName, Reason: $reason, Badge: $badge');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetails(context, recommendation),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getCategoryColor(category).withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: _getCategoryColor(category).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getCategoryColor(category).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _buildCompactProductImage(productId, productType),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name + Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1a1a1a),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rank Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getCategoryColor(category).withOpacity(0.15),
                                  _getCategoryColor(category).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getCategoryColor(category).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                color: _getCategoryColor(category),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(productType),
                              size: 12,
                              color: _getCategoryColor(category),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badge,
                              style: TextStyle(
                                color: _getCategoryColor(category),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Stats Row
                      Row(
                        children: [
                          // Views
                          _buildCompactStat(
                            Icons.visibility_outlined,
                            '$views',
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          // Distributors
                          _buildCompactStat(
                            Icons.store_outlined,
                            '$distributorCount',
                            Colors.green,
                          ),
                          const Spacer(),
                          // Add Button
                          _buildAddButton(context, recommendation, category),
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

  Widget _buildCompactProductImage(String productId, String productType) {
    return FutureBuilder<String?>(
      future: _getProductImageFromDatabase(productId, productType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getTypeColor(productType).withOpacity(0.7),
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildCompactPlaceholder(productType);
            },
          );
        }
        
        return _buildCompactPlaceholder(productType);
      },
    );
  }

  Widget _buildCompactPlaceholder(String productType) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTypeColor(productType).withOpacity(0.2),
            _getTypeColor(productType).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getTypeIcon(productType),
          size: 24,
          color: _getTypeColor(productType).withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, Map<String, dynamic> recommendation, String category) {
    return Container(
      height: 32,
              child: ElevatedButton(
              onPressed: () => _showAddProductDialog(context, recommendation),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryColor(category),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                elevation: 2,
                shadowColor: _getCategoryColor(category).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'أضف',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'trending':
        return Colors.purple;
      case 'surgical':
        return Colors.teal;
      case 'popular':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'catalog_product':
        return Icons.inventory_2;
      case 'surgical_tool':
        return Icons.medical_services;
      case 'ocr_product':
        return Icons.scanner;
      default:
        return Icons.shopping_bag;
    }
  }

  void _showProductDetails(BuildContext context, Map<String, dynamic> recommendation) {
    final category = recommendation['category'] ?? 'trending';
    final productType = recommendation['type'] ?? 'catalog_product';
    final productName = recommendation['name'] ?? 'تفاصيل التوصية';
    final productId = recommendation['id']?.toString() ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Card(
            elevation: 20,
            shadowColor: _getCategoryColor(category).withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(category).withOpacity(0.8),
                          _getCategoryColor(category),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Product Image
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: _buildProductImage(productId, productType),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Product Name
                        Text(
                          productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            recommendation['badge'] ?? 'مميز',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'المشاهدات',
                                  '${recommendation['views'] ?? 0}',
                                  Icons.visibility,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'الموزعين',
                                  '${recommendation['distributor_count'] ?? 0}',
                                  Icons.store,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'النقاط',
                                  '${recommendation['popularity'] ?? 0}',
                                  Icons.star,
                                  Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Reason
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(category).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getCategoryColor(category).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      color: _getCategoryColor(category),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'لماذا نوصي بهذا المنتج؟',
                                      style: TextStyle(
                                        color: _getCategoryColor(category),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  recommendation['reason'] ?? 'توصية ذكية',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: Colors.grey[300]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'إغلاق',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showAddProductDialog(context, recommendation);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getCategoryColor(category),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 3,
                                    shadowColor: _getCategoryColor(category).withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_shopping_cart, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'أضف للكتالوج',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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

  Widget _buildProductImage(String productId, String productType) {
    return FutureBuilder<String?>(
      future: _getProductImageFromDatabase(productId, productType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTypeColor(productType).withOpacity(0.7),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading image: ${snapshot.data}');
              return _buildPlaceholderImage(productType);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getTypeColor(productType).withOpacity(0.7),
                  ),
                ),
              );
            },
          );
        }
        
        return _buildPlaceholderImage(productType);
      },
    );
  }

  Future<String?> _getProductImageFromDatabase(String productId, String productType) async {
    try {
      print('🖼️ Fetching image for product $productId of type $productType');
      
      if (productId.isEmpty) return null;
      
      // محاولة جلب الصورة من الجدول المناسب
      switch (productType) {
        case 'catalog_product':
          final response = await Supabase.instance.client
              .from('products')
              .select('image_url, name')
              .eq('id', productId)
              .limit(1);
          
          if (response.isNotEmpty && response.first['image_url'] != null) {
            final imageUrl = response.first['image_url'].toString();
            print('✅ Found product image: $imageUrl');
            return imageUrl;
          }
          break;
          
        case 'surgical_tool':
          final response = await Supabase.instance.client
              .from('surgical_tools')
              .select('image_url, tool_name')
              .eq('id', productId)
              .limit(1);
          
          if (response.isNotEmpty && response.first['image_url'] != null) {
            final imageUrl = response.first['image_url'].toString();
            print('✅ Found surgical tool image: $imageUrl');
            return imageUrl;
          }
          break;
          
        case 'ocr_product':
          final response = await Supabase.instance.client
              .from('ocr_products')
              .select('image_url, product_name')
              .eq('id', productId)
              .limit(1);
          
          if (response.isNotEmpty && response.first['image_url'] != null) {
            final imageUrl = response.first['image_url'].toString();
            print('✅ Found OCR product image: $imageUrl');
            return imageUrl;
          }
          break;
      }
      
      print('⚠️ No image found for product $productId');
      return null;
      
    } catch (e) {
      print('❌ Error fetching product image: $e');
      return null;
    }
  }

  Widget _buildPlaceholderImage(String productType) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTypeColor(productType).withOpacity(0.3),
            _getTypeColor(productType).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getTypeIcon(productType),
          size: 32,
          color: _getTypeColor(productType),
        ),
      ),
    );
  }

  Color _getTypeColor(String productType) {
    switch (productType) {
      case 'catalog_product':
        return Colors.blue;
      case 'surgical_tool':
        return Colors.green;
      case 'ocr_product':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  void _showAddProductDialog(BuildContext context, Map<String, dynamic> recommendation) {
    final category = recommendation['category'] ?? 'trending';
    final productType = recommendation['type'] ?? 'catalog_product';
    final actionType = recommendation['action'] ?? 'add_to_catalog';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getTypeIcon(productType), color: _getCategoryColor(category)),
            const SizedBox(width: 8),
            const Text('إضافة توصية'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getCategoryColor(category).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '${recommendation['name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recommendation['badge'] ?? 'مميز',
                      style: TextStyle(
                        color: _getCategoryColor(category),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation['reason'] ?? 'توصية ذكية',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getActionMessage(actionType),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleAddRecommendation(context, recommendation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getCategoryColor(category),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: Text(_getActionButtonText(actionType)),
          ),
        ],
      ),
    );
  }

  String _getActionMessage(String actionType) {
    switch (actionType) {
      case 'add_to_catalog':
        return 'هل تريد إضافة هذا المنتج إلى كتالوجك؟';
      case 'add_surgical_tool':
        return 'هل تريد إضافة هذه الأداة الجراحية؟';
      case 'add_ocr_product':
        return 'هل تريد إضافة هذا المنتج؟';
      default:
        return 'هل تريد إضافة هذه التوصية؟';
    }
  }

  String _getActionButtonText(String actionType) {
    switch (actionType) {
      case 'add_to_catalog':
        return 'أضف للكتالوج';
      case 'add_surgical_tool':
        return 'أضف الأداة';
      case 'add_ocr_product':
        return 'أضف المنتج';
      default:
        return 'أضف';
    }
  }

  void _handleAddRecommendation(BuildContext context, Map<String, dynamic> recommendation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddFromCatalogScreen(
          catalogContext: CatalogContext.myProducts,
        ),
      ),
    );
  }
}


