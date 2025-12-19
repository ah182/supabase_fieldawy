// ignore_for_file: unused_element

import 'dart:async';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:fieldawy_store/widgets/user_details_sheet.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'review_system.dart';
import 'package:fieldawy_store/features/profile/application/blocking_service.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

    // دالة مساعدة لإخفاء الكيبورد
    void hideKeyboard() {
      if (searchFocusNode.hasFocus) {
        searchFocusNode.unfocus();
        // إعادة تعيين النص الشبحي إذا كان مربع البحث فارغاً
        if (searchController.text.isEmpty) {
          ghostText.value = '';
          fullSuggestion.value = '';
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => hideKeyboard(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('reviews_feature.title'.tr()),
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
                          hintText: 'reviews_feature.search_hint'.tr(),
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
                      'reviews_feature.no_results'.tr(namedArgs: {'query': debouncedSearchQuery.value}),
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
                      'reviews_feature.no_requests'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'reviews_feature.add_request_hint'.tr(),
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
              Text('reviews_feature.loading_reviews_error'.tr()),
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
          label: Text('reviews_feature.add_request_fab'.tr()),
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
        title: Text('reviews_feature.add_request_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('reviews_feature.select_source'.tr()),
            const SizedBox(height: 16),
            
            // خيار الكتالوج
            ListTile(
              leading: const Icon(Icons.library_books, color: Colors.blue),
              title: Text('reviews_feature.from_catalog'.tr()),
              subtitle: Text('reviews_feature.from_catalog_subtitle'.tr()),
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
                    // عرض dialog التعليق بعد اختيار المنتج
                    _showCommentDialog(
                      screenContext,
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
              title: Text('reviews_feature.from_gallery'.tr()),
              subtitle: Text('reviews_feature.from_gallery_subtitle'.tr()),
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
                    // عرض dialog التعليق بعد اختيار المنتج
                    _showCommentDialog(
                      screenContext,
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
            child: Text('reviews_feature.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // عرض dialog التعليق بعد اختيار المنتج
  void _showCommentDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> selectedProduct,
  ) {
    final commentController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('reviews_feature.add_comment_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // صورة المنتج
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: selectedProduct['product_image'] != null &&
                          selectedProduct['product_image'].isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: selectedProduct['product_image'],
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.medication,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.medication,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // اسم المنتج
              Text(
                selectedProduct['product_name'] ?? 'منتج',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              
              // حقل التعليق
              TextField(
                controller: commentController,
                maxLines: 4,
                maxLength: 300,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'reviews_feature.comment_hint'.tr(),
                  hintText: 'reviews_feature.comment_example'.tr(),
                  helperText: 'reviews_feature.comment_helper'.tr(),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.comment),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _createReviewRequestFromSelection(
                context,
                ref,
                selectedProduct,
                commentController.text.trim(),
              );
            },
            icon: const Icon(Icons.send),
            label: Text('reviews_feature.send_request'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _createReviewRequestFromSelection(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> selectedProduct,
    String requestComment, // جديد: التعليق
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
        SnackBar(content: Text('reviews_feature.product_id_missing_error'.tr())),
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
    
    // التحقق إذا كان المنتج مؤقتاً (OCR جديد لم يتم حفظه)
    final isTempOcr = selectedProduct['product_id'] == 'temp_ocr';
    
    final result = await service.createReviewRequest(
      productId: selectedProduct['product_id'],
      productType: selectedProduct['product_type'],
      requestComment: requestComment.isEmpty ? null : requestComment,
      customName: isTempOcr ? selectedProduct['product_name'] : null,
      customImage: isTempOcr ? selectedProduct['product_image'] : null,
      customPackage: isTempOcr ? selectedProduct['product_package'] : null,
    );
    print('📥 Result: $result');

    // إغلاق loading dialog
    navigator.pop();

    if (result['success'] == true) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('reviews_feature.create_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(activeReviewRequestsProvider);
    } else {
      String errorMessage = 'reviews_feature.report_error'.tr();
      if (result['error'] == 'product_already_requested') {
        errorMessage = 'reviews_feature.product_already_requested'.tr();
      } else if (result['error'] == 'weekly_limit_exceeded') {
        errorMessage = 'reviews_feature.weekly_limit'.tr();
      } else if (result['message'] != null) {
        errorMessage = result['message'];
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red, // جعل اللون أحمر عند الخطأ
          behavior: SnackBarBehavior.floating,
        ),
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
                            request.status == 'active' ? 'reviews_feature.active'.tr() : 'reviews_feature.closed'.tr(),
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
                    label: '${request.totalReviewsCount} ${"reviews_feature.ratings".tr()}',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),

                  // عدد التعليقات
                  _buildInfoChip(
                    icon: Icons.comment,
                    label: 'reviews_feature.comments_count'.tr(namedArgs: {'count': request.commentsCount.toString()}),
                    color: colorScheme.secondary,
                  ),
                  
                  // زر الحذف (فقط لصاحب الطلب)
                  if (isOwner) ...[
                    const Spacer(),
                    InkWell(
                      onTap: () => _confirmDeleteRequest(context, ref),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
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
                        'reviews_feature.text_comments'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'reviews_feature.comments_count'.tr(namedArgs: {'count': request.commentsCount.toString()}),
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

              // تعليق طالب التقييم (إذا كان موجوداً)
              if (request.requestComment != null && request.requestComment!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'reviews_feature.requester_comment'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              request.requestComment!,
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // طالب التقييم والتاريخ وزر الحذف
              Row(
                children: [
                  // صورة واسم طالب التقييم
                  GestureDetector(
                    onTap: () {
                      if (request.requesterRole == 'doctor') {
                        UserDetailsSheet.show(context, ref, request.requestedBy);
                      } else {
                        DistributorDetailsSheet.show(context, request.requestedBy);
                      }
                    },
                    child: Column(
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
                  ),
                  const Spacer(),
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(request.requestedAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
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
        return 'auth.role_veterinarian'.tr();
      case 'distributor':
        return 'auth.role_distributor'.tr();
      case 'company':
        return 'auth.role_company'.tr();
      case 'viewer':
        return 'مشاهد'; // Not standard role, keep as is or add to json
      default:
        return role;
    }
  }

  Future<void> _confirmDeleteRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reviews_feature.delete_request_title'.tr()),
        content: Text(
          'reviews_feature.delete_request_confirm'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('reviews_feature.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('reviews_feature.delete'.tr()), // Assuming delete key exists or added to reviews
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
      _showReviewInstructions(); // Show the instructions dialog
    });
    
    // Auto refresh كل 30 ثانية للحصول على تحديثات من المستخدمين الآخرين
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(productReviewsProvider);
        ref.invalidate(activeReviewRequestsProvider);
      }
    });
  }

  void _showReviewInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(FontAwesomeIcons.handHoldingHeart, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              'reviews_feature.honesty_charter'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Text(
                'reviews_feature.quran_verse'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'reviews_feature.honesty_msg1'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'reviews_feature.honesty_msg2'.tr(),
              style: const TextStyle(fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.green[700],
              ),
              child: Text('reviews_feature.pledge_button'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
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
        title: Text('reviews_feature.reviews_list_title'.tr()),
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
                
                // تعليق طالب التقييم (إذا كان موجوداً)
                if (widget.request.requestComment != null && widget.request.requestComment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تعليق طالب التقييم:',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.request.requestComment!,
                                style: textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    'reviews_feature.auto_delete_msg'.tr(),
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
                          'reviews_feature.no_reviews'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'reviews_feature.be_first'.tr(),
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
                child: Text('reviews_feature.loading_reviews_error'.tr()),
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
          label: Text('reviews_feature.add_my_review'.tr()),
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
              'reviews_feature.add_review_title'.tr(),
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
                  hintText: 'reviews_feature.comment_placeholder'.tr(),
                  border: const OutlineInputBorder(),
                  helperText:
                      'reviews_feature.comments_limit_helper'.tr(namedArgs: {'count': widget.request.commentsCount.toString()}),
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
                        'reviews_feature.comments_full_msg'.tr(),
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
                    child: Text('reviews_feature.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (rating == 0) {
                        setState(() {
                          errorMessage = 'reviews_feature.rating_required'.tr();
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
                            SnackBar(
                              content: Text('reviews_feature.review_added'.tr()),
                            ),
                          );
                          ref.invalidate(productReviewsProvider);
                          ref.invalidate(activeReviewRequestsProvider);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ??
                                  'reviews_feature.add_review_error_generic'.tr()),
                            ),
                          );
                        }
                      }
                    },
                    child: Text('reviews_feature.send'.tr()),
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
                InkWell(
                  onTap: () => _showUserDetails(context, ref, review.userId),
                  borderRadius: BorderRadius.circular(18),
                  child: CircleAvatar(
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
                ),
                const SizedBox(width: 8),
                // اسم المعلق والتاريخ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _showUserDetails(context, ref, review.userId),
                        child: Text(
                          review.userName.isEmpty ? 'surgical_tools_feature.comments.user'.tr() : review.userName,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    'reviews_feature.agree'.tr(namedArgs: {'count': review.helpfulCount.toString()}),
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
                             SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.delete_forever, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'reviews_feature.auto_deleted_message'.tr(),
                                      style: const TextStyle(fontSize: 14),
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
                    'reviews_feature.disagree'.tr(namedArgs: {'count': review.unhelpfulCount.toString()}),
                    style: TextStyle(
                      color: review.currentUserVotedUnhelpful ? Colors.red : null,
                    ),
                  ),
                ),
                // زر الحذف (فقط لصاحب التعليق)
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _confirmDeleteReview(context, ref),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ] else ...[
                  // زر الإبلاغ والحظر (للمستخدمين الآخرين)
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) async {
                      if (value == 'report') {
                        _showReportDialog(context, ref, review.id);
                      } else if (value == 'block') {
                        final blockingService = ref.read(blockingServiceProvider);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('reviews_feature.block_user'.tr()),
                            content: Text('reviews_feature.block_user_confirm'.tr()),
                            actions: [
                              TextButton(onPressed: ()=>Navigator.pop(context, false), child: Text('reviews_feature.cancel'.tr())),
                              TextButton(onPressed: ()=>Navigator.pop(context, true), child: Text('reviews_feature.block_user'.tr(), style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await blockingService.blockUser(review.userId);
                          // Refresh UI
                          ref.invalidate(productReviewsProvider);
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            const Icon(Icons.flag_outlined, size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('reviews_feature.report_content'.tr()),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('reviews_feature.block_user'.tr()),
                          ],
                        ),
                      ),
                    ],
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
        title: Text('reviews_feature.delete_review_title'.tr()),
        content: Text('reviews_feature.delete_review_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('reviews_feature.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('reviews_feature.delete'.tr()), // Assuming delete key exists or add to reviews
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
        SnackBar(
          content: Text('reviews_feature.review_deleted'.tr()),
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
          content: Text(result['message'] ?? 'reviews_feature.delete_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserDetails(BuildContext context, WidgetRef ref, String userId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userModel = await ref.read(userRepositoryProvider).getUser(userId);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        if (userModel != null) {
          _showUserBottomSheet(context, userModel);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل بيانات المستخدم')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  void _showUserBottomSheet(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    // ignore: unused_local_variable
    final isDoctor = user.role == 'doctor';
    final isDistributor = user.role == 'distributor' || user.role == 'company';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, // Increased height
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoUrl != null
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'comments_feature.user'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(user.role),
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
                  if (isDistributor && user.distributionMethod != null)
                    _buildDetailTile(
                      theme,
                      Icons.local_shipping,
                      'distributors_feature.distribution_method'.tr(),
                      _getDistributionMethodLabel(user.distributionMethod!),
                    ),
                  if (user.governorates != null && user.governorates!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                isDistributor ? 'distributors_feature.coverage_areas'.tr() : 'distributors_feature.location'.tr(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.governorates!.map((gov) => Container(
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
                          if (user.centers != null && user.centers!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.centers!.map((center) => Container(
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (user.whatsappNumber != null && user.whatsappNumber!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(context, user.whatsappNumber!),
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                        label: Text('distributors_feature.contact_whatsapp'.tr(), style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (isDistributor) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          final distributor = DistributorModel(
                            id: user.id,
                            displayName: user.displayName ?? '',
                            photoURL: user.photoUrl,
                            email: user.email,
                            distributorType: user.role,
                            whatsappNumber: user.whatsappNumber,
                            governorates: user.governorates,
                            centers: user.centers,
                            distributionMethod: user.distributionMethod,
                          );
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DistributorProductsScreen(
                                distributor: distributor,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.inventory_2),
                        label: Text('distributors_feature.view_products'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(ThemeData theme, IconData icon, String title, String value, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
      title: Text(title, style: theme.textTheme.bodySmall),
      subtitle: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'doctor': return 'auth.role_veterinarian'.tr();
      case 'distributor': return 'auth.role_distributor'.tr();
      case 'company': return 'auth.role_company'.tr();
      default: return role;
    }
  }

  String _getDistributionMethodLabel(String method) {
    switch (method) {
      case 'direct_distribution': return 'distributors_feature.direct'.tr();
      case 'order_delivery': return 'distributors_feature.delivery'.tr();
      case 'both': return 'distributors_feature.both'.tr();
      default: return method;
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'https://wa.me/20$cleanPhone';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح واتساب')),
          );
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref, String reviewId) {
    final reasons = [
      'reviews_feature.report_reasons.inappropriate'.tr(),
      'reviews_feature.report_reasons.spam'.tr(),
      'reviews_feature.report_reasons.misleading'.tr(),
      'reviews_feature.report_reasons.harassment'.tr(),
      'reviews_feature.report_reasons.other'.tr(),
    ];
    String selectedReason = reasons[0];
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'reviews_feature.report_content'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'reviews_feature.report_subtitle'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              // Reasons List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    final isSelected = selectedReason == reason;
                    return RadioListTile<String>(
                      title: Text(
                        reason,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (value) => setState(() => selectedReason = value!),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    );
                  },
                ),
              ),
              // Description Field
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'reviews_feature.report_details'.tr(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('reviews_feature.cancel'.tr(), style: const TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('reviews_feature.sending_report'.tr())),
                          );

                          final service = ref.read(reviewServiceProvider);
                          final result = await service.reportReview(
                            reviewId: reviewId,
                            reason: selectedReason,
                            description: descriptionController.text.trim().isEmpty 
                                ? null 
                                : descriptionController.text.trim(),
                          );

                          if (context.mounted) {
                             if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('reviews_feature.report_success'.tr()),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'reviews_feature.report_error'.tr()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text('reviews_feature.submit_report'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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


