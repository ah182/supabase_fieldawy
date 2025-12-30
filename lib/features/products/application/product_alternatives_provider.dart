import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
// ignore: unused_import
import 'package:collection/collection.dart';

/// Provider لجلب البدائل الذكية لمنتج معين
/// يستقبل [ProductModel] كمعامل لتحديد المادة الفعالة والمنتج الحالي
final productAlternativesProvider = FutureProvider.family<List<ProductModel>, ProductModel>((ref, currentProduct) async {
  // 1. الحصول على قائمة كل المنتجات المتاحة من الكاش
  final allProducts = await ref.watch(allDistributorProductsProvider.future);
  
  // إذا لم يكن للمنتج مادة فعالة، لا توجد بدائل
  if (currentProduct.activePrinciple == null || currentProduct.activePrinciple!.isEmpty) {
    return [];
  }

  // الحصول على بيانات المستخدم والموزعين للفلترة الجغرافية
  final userData = await ref.watch(userDataProvider.future);
  final allDistributors = await ref.watch(distributorsProvider.future);
  
  // تحويل قائمة الموزعين إلى Map لسرعة الوصول
  final distributorsMap = {
    for (var d in allDistributors) d.id: d
  };

  final targetPrinciple = currentProduct.activePrinciple!.toLowerCase().trim();
  final currentName = currentProduct.name.toLowerCase().trim(); // تنظيف اسم المنتج الحالي
  final currentId = currentProduct.id;

  // 2. الفلترة الذكية (نفس المادة الفعالة - ليس نفس المنتج - وليس نفس الاسم التجاري)
  final alternatives = allProducts.where((product) {
    if (product.id == currentId) return false;
    if (product.activePrinciple == null) return false;
    
    // استبعاد المنتج إذا كان له نفس الاسم التجاري (حتى لو من موزع آخر)
    final productName = product.name.toLowerCase().trim();
    if (productName == currentName) return false;

    final principle = product.activePrinciple!.toLowerCase().trim();
    return principle == targetPrinciple;
  }).toList();

  // 3. الترتيب الذكي (Smart Sorting)
  // الأولوية: القرب الجغرافي > السعر الأرخص
  alternatives.sort((a, b) {
    // أ) حساب نقاط القرب للمنتج A
    int scoreA = 0;
    if (userData != null && a.distributorUuid != null) {
      final distributorA = distributorsMap[a.distributorUuid];
      if (distributorA != null) {
        scoreA = LocationProximity.calculateProximityScore(
          userGovernorates: userData.governorates,
          userCenters: userData.centers,
          distributorGovernorates: distributorA.governorates,
          distributorCenters: distributorA.centers,
        );
      }
    }

    // ب) حساب نقاط القرب للمنتج B
    int scoreB = 0;
    if (userData != null && b.distributorUuid != null) {
      final distributorB = distributorsMap[b.distributorUuid];
      if (distributorB != null) {
        scoreB = LocationProximity.calculateProximityScore(
          userGovernorates: userData.governorates,
          userCenters: userData.centers,
          distributorGovernorates: distributorB.governorates,
          distributorCenters: distributorB.centers,
        );
      }
    }

    // المقارنة:
    // 1. إذا اختلفت نقاط القرب، الأكبر (الأقرب) يأتي أولاً
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA); // تنازلي
    }

    // 2. إذا تساوى القرب، الأرخص سعراً يأتي أولاً
    final priceA = a.price ?? double.infinity;
    final priceB = b.price ?? double.infinity;
    return priceA.compareTo(priceB); // تصاعدي
  });

  // 4. الخطوة الأهم: منع تكرار نفس "البديل" من موزعين مختلفين
  // بما أن القائمة مرتبة بالفعل بالأفضل (الأقرب ثم الأرخص)، سنأخذ أول نسخة تظهر من كل اسم تجاري
  final Map<String, ProductModel> uniqueAlternatives = {};
  for (var product in alternatives) {
    final nameKey = product.name.toLowerCase().trim();
    if (!uniqueAlternatives.containsKey(nameKey)) {
      uniqueAlternatives[nameKey] = product;
    }
  }

  // 5. إرجاع القائمة الفريدة
  return uniqueAlternatives.values.toList();
});