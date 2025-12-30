import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';

/// Provider لجلب البدائل الذكية لمنتج معين
/// يستقبل [ProductModel] كمعامل لتحديد المادة الفعالة والمنتج الحالي
final productAlternativesProvider = FutureProvider.family<List<ProductModel>, ProductModel>((ref, currentProduct) async {
  // 1. الحصول على قائمة كل المنتجات المتاحة من الكاش
  // نستخدم allDistributorProductsProvider لأنه يحتوي على المنتجات المحملة بالفعل
  final allProducts = await ref.watch(allDistributorProductsProvider.future);
  
  // إذا لم يكن للمنتج مادة فعالة، لا توجد بدائل
  if (currentProduct.activePrinciple == null || currentProduct.activePrinciple!.isEmpty) {
    return [];
  }

  final targetPrinciple = currentProduct.activePrinciple!.toLowerCase().trim();
  final currentId = currentProduct.id;

  // 2. الفلترة الذكية
  final alternatives = allProducts.where((product) {
    // استبعاد المنتج نفسه
    if (product.id == currentId) return false;
    
    // استبعاد المنتجات التي ليس لها مادة فعالة
    if (product.activePrinciple == null) return false;

    // مطابقة المادة الفعالة
    final principle = product.activePrinciple!.toLowerCase().trim();
    return principle == targetPrinciple;
  }).toList();

  // 3. الترتيب حسب السعر (من الأرخص للأغلى) - Smart Sorting
  alternatives.sort((a, b) {
    final priceA = a.price ?? double.infinity;
    final priceB = b.price ?? double.infinity;
    return priceA.compareTo(priceB);
  });

  // 4. إرجاع أفضل 10 بدائل فقط لعدم إزدحام الواجهة
  return alternatives.take(10).toList();
});
