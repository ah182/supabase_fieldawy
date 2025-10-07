import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferItem {
  final ProductModel product;
  final DateTime? expirationDate;
  OfferItem({required this.product, this.expirationDate});
}

/// مزود يعرض جميع العروض من جميع المستخدمين
final offersHomeProvider = FutureProvider<List<OfferItem>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // جلب جميع العروض من جميع المستخدمين
  final rows = await supabase
      .from('offers')
      .select()
      .order('created_at', ascending: false);

  final offers = <OfferItem>[];
  
  // جلب جميع أسماء المستخدمين مرة واحدة
  final userIds = rows
      .map((row) => row['user_id']?.toString())
      .where((id) => id != null)
      .toSet()
      .toList();
  
  Map<String, String> userNames = {};
  if (userIds.isNotEmpty) {
    final usersData = await supabase
        .from('users')
        .select('id, display_name')
        .inFilter('id', userIds);
    
    for (final user in usersData) {
      userNames[user['id'].toString()] = user['display_name']?.toString() ?? 'موزع غير معروف';
    }
  }
  
  for (final row in rows) {
    final isOcr = row['is_ocr'] as bool? ?? false;
    final productId = row['product_id']?.toString();
    final userId = row['user_id']?.toString();
    final distributorName = userNames[userId] ?? 'موزع غير معروف';
    final offerDescription = row['description']?.toString() ?? ''; // وصف العرض
    
    // تاريخ الصلاحية
    DateTime? expirationDate;
    final exp = row['expiration_date'];
    if (exp is String) {
      expirationDate = DateTime.tryParse(exp);
    } else if (exp is DateTime) {
      expirationDate = exp;
    }
    
    if (productId == null) continue;

    // جلب تفاصيل المنتج حسب النوع
    if (isOcr) {
      // منتج OCR
      final productDoc = await supabase
          .from('ocr_products')
          .select()
          .eq('id', productId)
          .maybeSingle();
      
      if (productDoc != null) {
        offers.add(OfferItem(
          product: ProductModel(
            id: productDoc['id']?.toString() ?? '',
            name: productDoc['product_name']?.toString() ?? '',
            description: offerDescription, // وصف العرض
            activePrinciple: productDoc['active_principle']?.toString(),
            company: productDoc['product_company']?.toString(),
            action: '',
            package: productDoc['package']?.toString() ?? '',
            imageUrl: (productDoc['image_url']?.toString() ?? '').startsWith('http')
                ? productDoc['image_url'].toString()
                : '',
            price: (row['price'] as num?)?.toDouble(),
            distributorId: distributorName, // اسم الموزع من جدول users
            createdAt: row['created_at'] != null
                ? DateTime.tryParse(row['created_at'].toString())
                : null,
            availablePackages: [productDoc['package']?.toString() ?? ''],
            selectedPackage: productDoc['package']?.toString() ?? '',
            isFavorite: false,
            oldPrice: null,
            priceUpdatedAt: null,
          ),
          expirationDate: expirationDate,
        ));
      }
    } else {
      // منتج عادي من الكتالوج
      final productDoc = await supabase
          .from('products')
          .select()
          .eq('id', int.tryParse(productId) ?? 0)
          .maybeSingle();
      
      if (productDoc != null) {
        final product = ProductModel.fromMap(Map<String, dynamic>.from(productDoc));
        offers.add(OfferItem(
          product: product.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: row['package'] as String?,
            distributorId: distributorName, // اسم الموزع من جدول users
            description: offerDescription, // وصف العرض
          ),
          expirationDate: expirationDate,
        ));
      }
    }
  }

  return offers;
});
