import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/data/expire_drugs_repository.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
export 'package:fieldawy_store/features/products/data/expire_drugs_repository.dart' show ExpireDrugItem;

/// مزود يعرض المنتجات التي لها تاريخ صلاحية من جميع الموزعين (مع الكاش)
final expireDrugsProvider = FutureProvider<List<ExpireDrugItem>>((ref) async {
  final repository = ref.watch(expireDrugsRepositoryProvider);
  return repository.getAllExpireDrugs();
});

/// مزود يعرض المنتجات التي لها تاريخ صلاحية للمستخدم الحالي فقط (مع الكاش)
final myExpireDrugsProvider = FutureProvider<List<ExpireDrugItem>>((ref) async {
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) {
    return [];
  }
  
  final repository = ref.watch(expireDrugsRepositoryProvider);
  return repository.getMyExpireDrugs(userId);
});

/// النسخة القديمة بدون كاش (محفوظة للتوافق)
/* final expireDrugsProvider = FutureProvider<List<ExpireDrugItem>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // جلب جميع المنتجات من distributor_products (من جميع الموزعين)
  final rows = await supabase
      .from('distributor_products')
      .select('*, views');

  // جلب جميع المنتجات من distributor_ocr_products (من جميع الموزعين)
  final ocrRows = await supabase
      .from('distributor_ocr_products')
      .select('*, views');

  // جلب تفاصيل المنتجات العادية
  final productIds = rows.map((row) => row['product_id'].toString()).toSet().toList();
  final productDocs = await supabase.from('products').select().inFilter('id', productIds);
  final productsMap = {
    for (var doc in productDocs)
      doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
  };

  // جلب تفاصيل منتجات OCR
  final ocrProductIds = ocrRows.map((row) => row['ocr_product_id'] as String).toSet().toList();
  final ocrProductDocs = await supabase.from('ocr_products').select().inFilter('id', ocrProductIds);
  final ocrProductsMap = {
    for (var doc in ocrProductDocs)
      doc['id'].toString(): ProductModel(
        id: doc['id']?.toString() ?? '',
        name: doc['product_name']?.toString() ?? '',
        description: '',
        activePrinciple: doc['active_principle']?.toString(),
        company: doc['product_company']?.toString(),
        action: '',
        package: doc['package']?.toString() ?? '',
        imageUrl: (doc['image_url']?.toString() ?? '').startsWith('http') ? doc['image_url'].toString() : '',
        price: null,
        distributorId: doc['distributor_name']?.toString(),
        createdAt: doc['created_at'] != null ? DateTime.tryParse(doc['created_at'].toString()) : null,
        availablePackages: [doc['package']?.toString() ?? ''],
        selectedPackage: doc['package']?.toString() ?? '',
        isFavorite: false,
        oldPrice: null,
        priceUpdatedAt: null,
      )
  };

  // دمج المنتجات التي لها expiration_date فقط
  final items = <ExpireDrugItem>[];

  // من المنتجات العادية
  for (final row in rows) {
    if (row['expiration_date'] != null) {
      final productDetails = productsMap[row['product_id'].toString()];
      if (productDetails != null) {
        DateTime? expirationDate;
        final exp = row['expiration_date'];
        if (exp is String) {
          expirationDate = DateTime.tryParse(exp);
        } else if (exp is DateTime) {
          expirationDate = exp;
        }
        items.add(ExpireDrugItem(
          product: productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: row['package'] as String?,
            distributorId: row['distributor_name'] as String?,
            views: (row['views'] as int?) ?? 0,
          ),
          expirationDate: expirationDate,
          isOcr: false,
        ));
      }
    }
  }

  // من منتجات OCR
  for (final row in ocrRows) {
    if (row['expiration_date'] != null) {
      final productDetails = ocrProductsMap[row['ocr_product_id']];
      if (productDetails != null) {
        DateTime? expirationDate;
        final exp = row['expiration_date'];
        if (exp is String) {
          expirationDate = DateTime.tryParse(exp);
        } else if (exp is DateTime) {
          expirationDate = exp;
        }
        // استخدم package من الصف إذا وجد، وإلا من المنتج نفسه
        final selectedPackage = row.containsKey('package') && row['package'] != null && (row['package'] as String).isNotEmpty
            ? row['package'] as String
            : (productDetails.selectedPackage ?? '');
        items.add(ExpireDrugItem(
          product: productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: selectedPackage,
            distributorId: row['distributor_name'] as String?,
            views: (row['views'] as int?) ?? 0,
          ),
          expirationDate: expirationDate,
          isOcr: true,
        ));
      }
    }
  }

  return items;
}); */

/*
final myExpireDrugsProviderOld = FutureProvider<List<ExpireDrugItem>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // جلب معرف المستخدم الحالي
  final userId = ref.watch(authServiceProvider).currentUser?.id;
  if (userId == null) {
    return []; // إذا لم يكن المستخدم مسجل دخول، أرجع قائمة فارغة
  }
  
  // جلب منتجات المستخدم الحالي فقط من distributor_products
  final rows = await supabase
      .from('distributor_products')
      .select('*, views')
      .eq('distributor_id', userId);

  // جلب منتجات المستخدم الحالي فقط من distributor_ocr_products
  final ocrRows = await supabase
      .from('distributor_ocr_products')
      .select('*, views')
      .eq('distributor_id', userId);

  // جلب تفاصيل المنتجات العادية
  final productIds = rows.map((row) => row['product_id'].toString()).toSet().toList();
  final productDocs = await supabase.from('products').select().inFilter('id', productIds);
  final productsMap = {
    for (var doc in productDocs)
      doc['id'].toString(): ProductModel.fromMap(Map<String, dynamic>.from(doc))
  };

  // جلب تفاصيل منتجات OCR
  final ocrProductIds = ocrRows.map((row) => row['ocr_product_id'] as String).toSet().toList();
  final ocrProductDocs = await supabase.from('ocr_products').select().inFilter('id', ocrProductIds);
  final ocrProductsMap = {
    for (var doc in ocrProductDocs)
      doc['id'].toString(): ProductModel(
        id: doc['id']?.toString() ?? '',
        name: doc['product_name']?.toString() ?? '',
        description: '',
        activePrinciple: doc['active_principle']?.toString(),
        company: doc['product_company']?.toString(),
        action: '',
        package: doc['package']?.toString() ?? '',
        imageUrl: (doc['image_url']?.toString() ?? '').startsWith('http') ? doc['image_url'].toString() : '',
        price: null,
        distributorId: doc['distributor_name']?.toString(),
        createdAt: doc['created_at'] != null ? DateTime.tryParse(doc['created_at'].toString()) : null,
        availablePackages: [doc['package']?.toString() ?? ''],
        selectedPackage: doc['package']?.toString() ?? '',
        isFavorite: false,
        oldPrice: null,
        priceUpdatedAt: null,
      )
  };

  // دمج المنتجات التي لها expiration_date فقط
  final items = <ExpireDrugItem>[];

  // من المنتجات العادية
  for (final row in rows) {
    if (row['expiration_date'] != null) {
      final productDetails = productsMap[row['product_id'].toString()];
      if (productDetails != null) {
        DateTime? expirationDate;
        final exp = row['expiration_date'];
        if (exp is String) {
          expirationDate = DateTime.tryParse(exp);
        } else if (exp is DateTime) {
          expirationDate = exp;
        }
        items.add(ExpireDrugItem(
          product: productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: row['package'] as String?,
            distributorId: row['distributor_name'] as String?,
            views: (row['views'] as int?) ?? 0,
          ),
          expirationDate: expirationDate,
          isOcr: false,
        ));
      }
    }
  }

  // من منتجات OCR
  for (final row in ocrRows) {
    if (row['expiration_date'] != null) {
      final productDetails = ocrProductsMap[row['ocr_product_id']];
      if (productDetails != null) {
        DateTime? expirationDate;
        final exp = row['expiration_date'];
        if (exp is String) {
          expirationDate = DateTime.tryParse(exp);
        } else if (exp is DateTime) {
          expirationDate = exp;
        }
        final selectedPackage = row.containsKey('package') && row['package'] != null && (row['package'] as String).isNotEmpty
            ? row['package'] as String
            : (productDetails.selectedPackage ?? '');
        items.add(ExpireDrugItem(
          product: productDetails.copyWith(
            price: (row['price'] as num?)?.toDouble(),
            selectedPackage: selectedPackage,
            distributorId: row['distributor_name'] as String?,
            views: (row['views'] as int?) ?? 0,
          ),
          expirationDate: expirationDate,
          isOcr: true,
        ));
      }
    }
  }

  return items;
}); */