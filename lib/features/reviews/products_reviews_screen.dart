import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'review_system.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';

// ============================================================================
// 🌟 MAIN SCREEN: المنتجات اللي عليها طلبات تقييم
// ============================================================================

class ProductsWithReviewsScreen extends HookConsumerWidget {
  const ProductsWithReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(activeReviewRequestsProvider);
    final theme = Theme.of(context);
    
    // Search functionality
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
    
    // Filter requests based on search
    final filteredRequests = useMemoized(() {
      if (requestsAsync is! AsyncData<List<ReviewRequestModel>>) {
        return <ReviewRequestModel>[];
      }
      final requests = requestsAsync.value;
      if (debouncedSearchQuery.value.isEmpty) {
        return requests;
      }
      final query = debouncedSearchQuery.value.toLowerCase();
      return requests.where((request) {
        return request.productName.toLowerCase().contains(query) ||
               (request.productPackage ?? '').toLowerCase().contains(query) ||
               request.requesterName.toLowerCase().contains(query);
      }).toList();
    }, [requestsAsync, debouncedSearchQuery.value]);

    return GestureDetector(
      onTap: () => searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المنتجات المطلوب تقييمها'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Column(
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (value) {
                          searchQuery.value = value;
                          if (value.isNotEmpty && requestsAsync is AsyncData<List<ReviewRequestModel>>) {
                            // ignore: unnecessary_cast
                            final requests = (requestsAsync as AsyncData<List<ReviewRequestModel>>).value;
                            final filtered = requests.where((request) {
                              final productName = request.productName.toLowerCase();
                              return productName.startsWith(value.toLowerCase());
                            }).toList();
                            
                            if (filtered.isNotEmpty) {
                              final suggestion = filtered.first;
                              ghostText.value = suggestion.productName;
                              fullSuggestion.value = suggestion.productName;
                            } else {
                              ghostText.value = '';
                              fullSuggestion.value = '';
                            }
                          } else {
                            ghostText.value = '';
                            fullSuggestion.value = '';
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'ابحث عن منتج...',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
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
                        top: 11,
                        right: 71,
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
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.secondary.withOpacity(0.1)
                                  : theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ghostText.value,
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: requestsAsync.when(
          data: (requests) {
            final displayRequests = debouncedSearchQuery.value.isEmpty ? requests : filteredRequests;
            
            if (displayRequests.isEmpty && debouncedSearchQuery.value.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد نتائج للبحث عن "${debouncedSearchQuery.value}"',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            if (requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد منتجات مطلوب تقييمها حالياً',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط على + لإضافة طلب تقييم',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeReviewRequestsProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayRequests.length,
                itemBuilder: (context, index) {
                  final request = displayRequests[index];
                  return ProductReviewCard(
                    request: request,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductReviewDetailsScreen(request: request),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('حدث خطأ: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(activeReviewRequestsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddReviewRequestDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('إضافة طلب تقييم'),
        ),
      ),
    );
  }

  void _showAddReviewRequestDialog(BuildContext context, WidgetRef ref) {
    // حفظ الـ context الأصلي من ProductsWithReviewsScreen
    final screenContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة طلب تقييم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر مصدر المنتج:'),
            const SizedBox(height: 16),
            
            // خيار الكتالوج
            ListTile(
              leading: const Icon(Icons.library_books, color: Colors.blue),
              title: const Text('من الكتالوج'),
              subtitle: const Text('اختر من المنتجات الموجودة'),
              onTap: () {
                Navigator.pop(dialogContext); // نقفل الـ dialog
                Navigator.push(
                  screenContext, // نستخدم screen context
                  MaterialPageRoute(
                    builder: (context) => const AddFromCatalogScreen(
                      catalogContext: CatalogContext.reviews,
                      isFromReviewRequest: true,
                    ),
                  ),
                ).then((selectedProduct) {
                  if (selectedProduct != null) {
                    _createReviewRequestFromSelection(
                      screenContext, // نستخدم screen context
                      ref,
                      selectedProduct,
                    );
                  }
                });
              },
            ),
            
            const Divider(),
            
            // خيار المعرض
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('من المعرض'),
              subtitle: const Text('التقط صورة أو اختر من المعرض'),
              onTap: () {
                Navigator.pop(dialogContext); // نقفل الـ dialog
                Navigator.push(
                  screenContext, // نستخدم screen context
                  MaterialPageRoute(
                    builder: (context) => const AddProductOcrScreen(
                      isFromReviewRequest: true,
                      showExpirationDate: false,  // إخفاء حقل الصلاحية
                    ),
                  ),
                ).then((selectedProduct) {
                  if (selectedProduct != null) {
                    _createReviewRequestFromSelection(
                      screenContext, // نستخدم screen context
                      ref,
                      selectedProduct,
                    );
                  }
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _createReviewRequestFromSelection(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> selectedProduct,
  ) async {
    // Debug: طباعة البيانات المُرسلة
    print('📦 Selected Product Data:');
    print('   Full Map: $selectedProduct');
    print('   product_id: ${selectedProduct['product_id']}');
    print('   product_id type: ${selectedProduct['product_id'].runtimeType}');
    print('   product_type: ${selectedProduct['product_type']}');
    
    // حفظ navigator state قبل الـ await
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // التحقق من صحة البيانات قبل الإرسال
    if (selectedProduct['product_id'] == null || selectedProduct['product_id'].toString().isEmpty) {
      print('❌ ERROR: product_id is null or empty!');
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('خطأ: معرف المنتج غير موجود')),
      );
      return;
    }
    
    // عرض loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    final service = ref.read(reviewServiceProvider);
    print('🚀 Calling createReviewRequest...');
    final result = await service.createReviewRequest(
      productId: selectedProduct['product_id'],
      productType: selectedProduct['product_type'],
    );
    print('📥 Result: $result');

    // إغلاق loading dialog
    navigator.pop();

    if (result['success'] == true) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('تم إنشاء طلب التقييم بنجاح')),
      );
      ref.invalidate(activeReviewRequestsProvider);
    } else {
      String errorMessage = 'حدث خطأ';
      if (result['error'] == 'product_already_requested') {
        errorMessage = 'تم طلب تقييم هذا المنتج مسبقاً';
      } else if (result['error'] == 'weekly_limit_exceeded') {
        errorMessage = 'يمكنك طلب تقييم منتج واحد فقط كل أسبوع';
      } else if (result['message'] != null) {
        errorMessage = result['message'];
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }
}

// ============================================================================
// 🎨 PRODUCT REVIEW CARD (في القائمة)
// ============================================================================

class ProductReviewCard extends ConsumerWidget {
  final ReviewRequestModel request;
  final VoidCallback onTap;

  const ProductReviewCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == request.requestedBy;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة المنتج واسم المنتج
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // صورة المنتج
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: request.productImage != null
                        ? Image.network(
                            request.productImage!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  // اسم المنتج والباكدج والحالة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اسم المنتج
                        Text(
                          request.productName,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.productPackage != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.widgets_outlined, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: request.productPackage!
                                      .split('-')
                                      .map((package) => package.trim())
                                      .where((package) => package.isNotEmpty)
                                      .map((package) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: colorScheme.primary.withOpacity(0.3),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              package,
                                              style: textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onPrimaryContainer,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // حالة الطلب
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: request.status == 'active'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: request.status == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          child: Text(
                            request.status == 'active' ? 'نشط' : 'مغلق',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: request.status == 'active'
                                  ? Colors.green[700]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // معلومات التقييم
              Row(
                children: [
                  // متوسط التقييم
                  if (request.avgRating != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.avgRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // عدد التقييمات
                  _buildInfoChip(
                    icon: Icons.rate_review,
                    label: '${request.totalReviewsCount} تقييم',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),

                  // عدد التعليقات
                  _buildInfoChip(
                    icon: Icons.comment,
                    label: '${request.commentsCount}/5',
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar للتعليقات
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التعليقات النصية',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${request.commentsCount}/5',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: request.isCommentsFull
                              ? Colors.green
                              : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: request.commentsCount / 5,
                    backgroundColor: colorScheme.surfaceVariant,
                    color: request.isCommentsFull
                        ? Colors.green
                        : colorScheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // طالب التقييم والتاريخ وزر الحذف
              Row(
                children: [
                  // صورة واسم طالب التقييم
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: request.requesterPhoto != null
                            ? NetworkImage(request.requesterPhoto!)
                            : null,
                        backgroundColor: colorScheme.primaryContainer,
                        child: request.requesterPhoto == null
                            ? Icon(Icons.person, size: 16, color: colorScheme.onPrimaryContainer)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.requesterName,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // دور طالب التقييم
                  if (request.requesterRole != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(request.requesterRole!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getRoleLabel(request.requesterRole!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(request.requesterRole!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(request.requestedAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  // زر الحذف (فقط لصاحب الطلب)
                  if (isOwner) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteRequest(context, ref),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return Colors.green;
      case 'distributor':
        return Colors.blue;
      case 'company':
        return Colors.purple;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return 'طبيب بيطري';
      case 'distributor':
        return 'موزع فردي';
      case 'company':
        return 'شركة توزيع';
      case 'viewer':
        return 'مشاهد';
      default:
        return role;
    }
  }

  Future<void> _confirmDeleteRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف طلب التقييم'),
        content: const Text(
          'هل أنت متأكد من حذف طلب التقييم؟\n\n'
          '⚠️ سيتم حذف جميع التقييمات المرتبطة به',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final service = ref.read(reviewServiceProvider);
    final result = await service.deleteMyReviewRequest(request.id);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف طلب التقييم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(activeReviewRequestsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ في الحذف'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

// ============================================================================
// 📋 PRODUCT REVIEW DETAILS SCREEN (تفاصيل التقييمات)
// ============================================================================

class ProductReviewDetailsScreen extends ConsumerStatefulWidget {
  final ReviewRequestModel request;

  const ProductReviewDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  ConsumerState<ProductReviewDetailsScreen> createState() =>
      _ProductReviewDetailsScreenState();
}

class _ProductReviewDetailsScreenState
    extends ConsumerState<ProductReviewDetailsScreen> {
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    // Auto refresh عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(productReviewsProvider);
      ref.invalidate(activeReviewRequestsProvider);
    });
    
    // Auto refresh كل 30 ثانية للحصول على تحديثات من المستخدمين الآخرين
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(productReviewsProvider);
        ref.invalidate(activeReviewRequestsProvider);
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // مراقبة التقييمات للحصول على التحديثات الفورية
    final reviewsAsync = ref.watch(productReviewsProvider((
      productId: widget.request.productId,
      productType: widget.request.productType,
    )));
    
    // استخدام ref.watch للحصول على البيانات المحدثة مع key مختلف
    final activeRequestsAsync = ref.watch(activeReviewRequestsProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // البحث عن الـ request المحدث من الـ provider
    // إذا لم يتم العثور عليه، نستخدم widget.request
    final updatedRequest = activeRequestsAsync.maybeWhen(
      data: (requests) {
        try {
          return requests.firstWhere((r) => r.id == widget.request.id);
        } catch (e) {
          return widget.request;
        }
      },
      orElse: () => widget.request,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييمات المنتج'),
      ),
      body: Column(
        children: [
          // Header: اسم المنتج والإحصائيات
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // صف واحد: صورة المنتج + المعلومات + التقييم
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // صورة المنتج
                    if (widget.request.productImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.request.productImage!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildProductPlaceholder(),
                        ),
                      )
                    else
                      _buildProductPlaceholder(),
                    const SizedBox(width: 12),
                    
                    // معلومات المنتج
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.request.productName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.request.productPackage != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.widgets_outlined, size: 12, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: widget.request.productPackage!
                                        .split('-')
                                        .map((package) => package.trim())
                                        .where((package) => package.isNotEmpty)
                                        .map((package) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primaryContainer.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: colorScheme.primary.withOpacity(0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Text(
                                                package,
                                                style: textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onPrimaryContainer,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // التقييم
                    if (widget.request.avgRating != null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 17),
                                const SizedBox(width: 4),
                                Text(
                                  widget.request.avgRating!.toStringAsFixed(1),
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // الإحصائيات
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactStatItem(
                      icon: Icons.rate_review,
                      label: 'تقييم',
                      value: updatedRequest.totalReviewsCount,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    _buildCompactStatItem(
                      icon: Icons.comment,
                      label: 'تعليق',
                      value: updatedRequest.commentsCount,
                      color: colorScheme.secondary,
                    ),
                  ],
                ),

                // حالة التعليقات
                if (!updatedRequest.canAddComment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'اكتمل عدد التعليقات (5/5)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // رسالة تعريفية دائمة عن قاعدة الحذف التلقائي
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 54, 137, 225).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color.fromARGB(255, 74, 105, 216), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'التعليقات التي تصل لـ 10 تقييمات "لا اتفق" يتم حذفها تلقائياً',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color.fromARGB(255, 11, 129, 171),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قائمة التقييمات
          Expanded(
            child: reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد تقييمات بعد',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'كن أول من يقيم هذا المنتج',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh كل البيانات
                    ref.invalidate(productReviewsProvider);
                    ref.invalidate(activeReviewRequestsProvider);
                    
                    // انتظار التحديث
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      return ReviewDetailCard(
                        review: reviews[index],
                        productId: widget.request.productId,
                        productType: widget.request.productType,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('حدث خطأ: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAddReviewButton(context),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, size: 30, color: Colors.grey[400]),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildAddReviewButton(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return null;

    // منع صاحب الطلب من التقييم
    if (currentUserId == widget.request.requestedBy) {
      return null;
    }

    final reviewsAsync = ref.watch(productReviewsProvider((
      productId: widget.request.productId,
      productType: widget.request.productType,
    )));

    return reviewsAsync.maybeWhen(
      data: (reviews) {
        final userReview =
            reviews.where((r) => r.userId == currentUserId).firstOrNull;
        if (userReview != null) return null;

        return FloatingActionButton.extended(
          onPressed: () => _showAddReviewDialog(context),
          icon: const Icon(Icons.add_comment),
          label: const Text('إضافة تقييمي'),
        );
      },
      orElse: () => null,
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    int rating = 0;
    final commentController = TextEditingController();
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أضف تقييمك',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: RatingInput(
                onRatingChanged: (value) {
                  rating = value;
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            // رسالة الخطأ
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.request.isCommentsFull) ...[
              TextField(
                controller: commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك (اختياري)',
                  border: const OutlineInputBorder(),
                  helperText:
                      'التعليقات محدودة (${widget.request.commentsCount}/5)',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اكتمل عدد التعليقات. يمكنك إضافة تقييم بالنجوم فقط',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (rating == 0) {
                        setState(() {
                          errorMessage = '⭐ يجب اختيار التقييم بالنجوم أولاً';
                        });
                        return;
                      }

                      final service = ref.read(reviewServiceProvider);
                      final result = await service.addProductReview(
                        requestId: widget.request.id,
                        rating: rating,
                        comment: commentController.text.trim().isEmpty
                            ? null
                            : commentController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إضافة تقييمك بنجاح'),
                            ),
                          );
                          ref.invalidate(productReviewsProvider);
                          ref.invalidate(activeReviewRequestsProvider);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ??
                                  'حدث خطأ في إضافة التقييم'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('إرسال'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🎨 REVIEW DETAIL CARD (في صفحة التفاصيل)
// ============================================================================

class ReviewDetailCard extends ConsumerWidget {
  final ProductReviewModel review;
  final String productId;
  final String productType;

  const ReviewDetailCard({
    super.key, 
    required this.review,
    required this.productId,
    required this.productType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == review.userId;
    
    // Debug
    print('🎨 ReviewDetailCard: userName="${review.userName}", userId=${review.userId}');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User info + Rating
            Row(
              children: [
                // صورة المعلق
                CircleAvatar(
                  radius: 18,
                  backgroundImage: review.userPhoto != null
                      ? NetworkImage(review.userPhoto!)
                      : null,
                  backgroundColor: colorScheme.primaryContainer,
                  child: review.userPhoto == null
                      ? Text(
                          review.userName.isNotEmpty
                              ? review.userName[0].toUpperCase()
                              : '؟',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                // اسم المعلق والتاريخ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName.isEmpty ? 'مستخدم' : review.userName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDate(review.createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          if (review.isVerifiedPurchase) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // النجوم
                RatingStars(rating: review.rating.toDouble(), size: 16),
              ],
            ),

            // Comment
            if (review.hasComment && review.comment != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  review.comment!,
                  style: textTheme.bodySmall,
                ),
              ),
            ],

            // Actions: Helpful and Unhelpful buttons
            const SizedBox(height: 8),
            Row(
              children: [
                // Like button
                TextButton.icon(
                  onPressed: () async {
                    print('👍 Voting helpful for review: ${review.id}');
                    print('   Before: helpful=${review.helpfulCount}, unhelpful=${review.unhelpfulCount}');
                    print('   Already voted: helpful=${review.currentUserVotedHelpful}, unhelpful=${review.currentUserVotedUnhelpful}');
                    
                    final service = ref.read(reviewServiceProvider);
                    final result = await service.voteReviewHelpful(
                      reviewId: review.id,
                      isHelpful: true,
                    );
                    
                    print('   API Result: $result');
                    print('   New counts from API: helpful=${result['helpful_count']}, unhelpful=${result['unhelpful_count']}');
                    
                    if (result['success'] == true) {
                      // Force refresh البيانات
                      await Future.delayed(const Duration(milliseconds: 300));
                      final _ = ref.refresh(productReviewsProvider((
                        productId: productId,
                        productType: productType,
                      )));
                      
                      // Refresh الـ header counts أيضاً
                      ref.invalidate(activeReviewRequestsProvider);
                      await Future.delayed(const Duration(milliseconds: 100));
                      // ignore: unused_result
                      ref.refresh(activeReviewRequestsProvider);
                      
                      print('   Provider refreshed');
                    }
                  },
                  icon: Icon(
                    review.currentUserVotedHelpful
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 16,
                    color: review.currentUserVotedHelpful ? Colors.green : null,
                  ),
                  label: Text(
                    'اتفق (${review.helpfulCount})',
                    style: TextStyle(
                      color: review.currentUserVotedHelpful ? Colors.green : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dislike button
                TextButton.icon(
                  onPressed: () async {
                    print('👎 Voting unhelpful for review: ${review.id}');
                    print('   Before: helpful=${review.helpfulCount}, unhelpful=${review.unhelpfulCount}');
                    print('   Already voted: helpful=${review.currentUserVotedHelpful}, unhelpful=${review.currentUserVotedUnhelpful}');
                    
                    final service = ref.read(reviewServiceProvider);
                    final result = await service.voteReviewHelpful(
                      reviewId: review.id,
                      isHelpful: false,
                    );
                    
                    print('   API Result: $result');
                    print('   New counts from API: helpful=${result['helpful_count']}, unhelpful=${result['unhelpful_count']}');
                    
                    if (result['success'] == true) {
                      // التحقق من حذف التعليق (unhelpful >= 10)
                      final unhelpfulCount = result['unhelpful_count'] ?? 0;
                      final wasDeleted = unhelpfulCount >= 10;
                      
                      if (wasDeleted) {
                        print('⚠️ Review was auto-deleted due to too many dislikes');
                        // عرض رسالة في آخر الصفحة
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.delete_forever, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '🗑️ تم حذف التعليق تلقائياً بعد وصوله لـ 10 تقييمات "غير مفيد"',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      
                      // Force refresh البيانات (سواء اتحذف أو لا)
                      await Future.delayed(const Duration(milliseconds: 300));
                      final _ = ref.refresh(productReviewsProvider((
                        productId: productId,
                        productType: productType,
                      )));
                      
                      // Refresh الـ header counts أيضاً
                      ref.invalidate(activeReviewRequestsProvider);
                      await Future.delayed(const Duration(milliseconds: 100));
                      // ignore: unused_result
                      ref.refresh(activeReviewRequestsProvider);
                      
                      print('   Provider refreshed');
                    }
                  },
                  icon: Icon(
                    review.currentUserVotedUnhelpful
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    size: 16,
                    color: review.currentUserVotedUnhelpful ? Colors.red : null,
                  ),
                  label: Text(
                    ' لا اتفق (${review.unhelpfulCount})',
                    style: TextStyle(
                      color: review.currentUserVotedUnhelpful ? Colors.red : null,
                    ),
                  ),
                ),
                // زر الحذف (فقط لصاحب التعليق)
                if (isOwner) ...[
                  const SizedBox(width: 13),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteReview(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(''),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteReview(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('هل أنت متأكد من حذف تقييمك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final service = ref.read(reviewServiceProvider);
    final result = await service.deleteMyReview(review.id);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف التقييم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh كل البيانات المرتبطة فوراً
      ref.invalidate(productReviewsProvider);
      ref.invalidate(activeReviewRequestsProvider);
      
      // Force refresh مباشر
      await Future.delayed(const Duration(milliseconds: 100));
      final _ = ref.refresh(activeReviewRequestsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ في الحذف'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}


