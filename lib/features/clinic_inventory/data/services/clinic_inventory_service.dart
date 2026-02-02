import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic_inventory_item.dart';
import '../models/inventory_transaction.dart';
import 'clinic_assistant_auth_service.dart';

/// خدمة جرد العيادة
class ClinicInventoryService {
  final SupabaseClient _supabase;
  final Ref _ref;

  ClinicInventoryService(this._supabase, this._ref);

  /// الحصول على user ID الحالي
  /// If in Assistant Mode, return the doctor's ID.
  /// Otherwise, return the specific authenticated user ID.
  String? get _currentUserId {
    final assistantTargetId = _ref.read(clinicAssistantUserIdProvider);
    if (assistantTargetId != null) {
      return assistantTargetId;
    }
    return _supabase.auth.currentUser?.id;
  }

  // ==================== جلب البيانات ====================

  /// جلب جميع عناصر الجرد
  Future<List<ClinicInventoryItem>> getInventoryItems({
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase
          .from('clinic_inventory')
          .select()
          .eq('user_id', _currentUserId!);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => ClinicInventoryItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      rethrow;
    }
  }

  /// جلب عنصر واحد
  Future<ClinicInventoryItem?> getInventoryItem(String id) async {
    try {
      final response = await _supabase
          .from('clinic_inventory')
          .select()
          .eq('id', id)
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (response == null) return null;
      return ClinicInventoryItem.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching inventory item: $e');
      rethrow;
    }
  }

  /// البحث في الجرد
  Future<List<ClinicInventoryItem>> searchInventory(String query) async {
    try {
      final response = await _supabase
          .from('clinic_inventory')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('is_active', true)
          .or('product_name.ilike.%$query%,company.ilike.%$query%')
          .order('product_name');

      return (response as List)
          .map((json) => ClinicInventoryItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error searching inventory: $e');
      rethrow;
    }
  }

  /// البحث عن صورة منتج في الكتالوج العام بالاسم
  Future<String?> findProductImageByName(String name) async {
    try {
      if (name.trim().isEmpty) return null;

      // نبحث في جدول products العام
      final response = await _supabase
          .from('products')
          .select('image_url')
          .ilike('name', '%${name.trim()}%')
          .limit(1)
          .maybeSingle();

      if (response != null && response['image_url'] != null) {
        return response['image_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error finding product image: $e');
      return null;
    }
  }

  // ==================== إضافة وتعديل ====================

  /// إضافة عنصر جديد للجرد
  Future<ClinicInventoryItem> addInventoryItem({
    required String productName,
    required String package, // e.g. "100 ml", "2 strips"
    String? company,
    String? imageUrl,
    required int quantity, // Number of full units (boxes, bottles)
    required double purchasePrice, // Purchase price per unit (box)
    double unitSize = 1, // e.g. 100 (ml), 20 (tabs)
    String unitType = 'box', // e.g. 'ml', 'tablet'
    String packageType = 'box', // e.g. 'bottle', 'vial'
    int minStock = 3,
    DateTime? expiryDate,
    String sourceType = 'manual',
    String? sourceProductId,
    String? sourceOcrProductId,
    String? notes,
  }) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    try {
      final item = ClinicInventoryItem(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        sourceType: sourceType,
        sourceProductId: sourceProductId,
        sourceOcrProductId: sourceOcrProductId,
        productName: productName,
        package: package,
        company: company,
        imageUrl: imageUrl,
        quantity: quantity,
        unitSize: unitSize,
        unitType: unitType,
        packageType: packageType,
        minStock: minStock,
        purchasePrice: purchasePrice,
        expiryDate: expiryDate,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final data = await _supabase
          .from('clinic_inventory')
          .insert(item.toInsertJson())
          .select()
          .single();

      final newItem = ClinicInventoryItem.fromJson(data);

      // تسجيل عملية الإضافة
      await _recordTransaction(
        inventoryId: newItem.id, // استخدام الـ ID الحقيقي من قاعدة البيانات
        type: TransactionType.add,
        productName: productName,
        package: package,
        boxesAdded: quantity,
        unitSold:
            packageType, // Use packageType for transaction unit if sensible
        purchasePricePerBox: purchasePrice,
        notes: 'إضافة أولية',
      );

      return newItem;
    } catch (e) {
      debugPrint('Error adding inventory item: $e');
      rethrow;
    }
  }

  /// تحديث منتج في الجرد
  Future<void> updateInventoryItem({
    required String id,
    String? productName,
    String? package,
    String? company,
    String? imageUrl,
    int? quantity,
    double? purchasePrice,
    double? unitSize,
    String? unitType,
    String? packageType,
    int? minStock,
    DateTime? expiryDate,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (productName != null) updates['product_name'] = productName;
      if (package != null) updates['package'] = package;
      if (company != null) updates['company'] = company;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (quantity != null) updates['quantity'] = quantity;
      if (purchasePrice != null) updates['purchase_price'] = purchasePrice;
      if (unitSize != null) updates['unit_size'] = unitSize;
      if (unitType != null) updates['unit_type'] = unitType;
      if (packageType != null) updates['package_type'] = packageType;
      if (minStock != null) updates['min_stock'] = minStock;
      if (expiryDate != null) {
        updates['expiry_date'] = expiryDate.toIso8601String().split('T')[0];
      }
      if (notes != null) updates['notes'] = notes;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('clinic_inventory')
          .update(updates)
          .eq('id', id)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      rethrow;
    }
  }

  /// حذف منتج من الجرد
  Future<void> deleteInventoryItem(String id) async {
    try {
      await _supabase
          .from('clinic_inventory')
          .delete()
          .eq('id', id)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      rethrow;
    }
  }

  /// إضافة كمية لعنصر موجود
  Future<ClinicInventoryItem> addQuantity({
    required String inventoryId,
    required int boxesToAdd,
    required double purchasePricePerBox,
    String? notes,
  }) async {
    try {
      // جلب العنصر الحالي
      final currentItem = await getInventoryItem(inventoryId);
      if (currentItem == null) {
        throw Exception('Item not found');
      }

      // تحديث الكمية
      final newQuantity = currentItem.quantity + boxesToAdd;

      // حساب متوسط سعر الشراء (اختياري - يمكن استخدام السعر الجديد فقط)
      final totalOldCost = currentItem.quantity * currentItem.purchasePrice;
      final totalNewCost = boxesToAdd * purchasePricePerBox;
      final newAveragePrice = (totalOldCost + totalNewCost) / newQuantity;

      final response = await _supabase
          .from('clinic_inventory')
          .update({
            'quantity': newQuantity,
            'purchase_price': newAveragePrice,
          })
          .eq('id', inventoryId)
          .eq('user_id', _currentUserId!)
          .select()
          .single();

      // تسجيل عملية الإضافة
      await _recordTransaction(
        inventoryId: inventoryId,
        type: TransactionType.add,
        productName: currentItem.productName,
        package: currentItem.package,
        boxesAdded: boxesToAdd,
        purchasePricePerBox: purchasePricePerBox,
        notes: notes,
      );

      return ClinicInventoryItem.fromJson(response);
    } catch (e) {
      debugPrint('Error adding quantity: $e');
      rethrow;
    }
  }

  // ==================== البيع ====================

  /// بيع كمية (علبة كاملة أو جزئي)
  Future<ClinicInventoryItem> sellQuantity({
    required String inventoryId,
    required double quantitySold,
    required String unitSold, // 'box', 'ml', 'gram'
    required double sellingPrice,
    String? notes,
  }) async {
    try {
      final currentItem = await getInventoryItem(inventoryId);
      if (currentItem == null) {
        throw Exception('Item not found');
      }

      int newQuantity = currentItem.quantity;
      double newPartialQuantity = currentItem.partialQuantity;
      double costOfSold = 0;

      if (unitSold == 'box') {
        // بيع علب كاملة
        final boxesSold = quantitySold.toInt();
        if (boxesSold > newQuantity) {
          throw Exception(
              'الكمية المطلوبة غير متوفرة / Requested quantity not available');
        }
        newQuantity -= boxesSold;
        costOfSold = boxesSold * currentItem.purchasePrice;
      } else {
        // بيع جزئي (ml أو gram)
        final totalAvailable = currentItem.totalQuantityInUnits;
        if (quantitySold > totalAvailable) {
          throw Exception(
              'الكمية المطلوبة غير متوفرة / Requested quantity not available');
        }

        // حساب التكلفة
        costOfSold = quantitySold * currentItem.pricePerUnit;

        // خصم من الجزئي أولاً، ثم من العلب
        double remaining = quantitySold;

        if (newPartialQuantity >= remaining) {
          newPartialQuantity -= remaining;
        } else {
          remaining -= newPartialQuantity;
          newPartialQuantity = 0;

          // خصم من العلب
          while (remaining > 0 && newQuantity > 0) {
            newQuantity--;
            newPartialQuantity = currentItem.unitSize;
            if (newPartialQuantity >= remaining) {
              newPartialQuantity -= remaining;
              remaining = 0;
            } else {
              remaining -= newPartialQuantity;
              newPartialQuantity = 0;
            }
          }
        }
      }

      final profit = sellingPrice - costOfSold;

      // تحديث المخزون
      final response = await _supabase
          .from('clinic_inventory')
          .update({
            'quantity': newQuantity,
            'partial_quantity': newPartialQuantity,
          })
          .eq('id', inventoryId)
          .eq('user_id', _currentUserId!)
          .select()
          .single();

      // تسجيل عملية البيع
      await _recordTransaction(
        inventoryId: inventoryId,
        type: TransactionType.sell,
        productName: currentItem.productName,
        package: currentItem.package,
        quantitySold: quantitySold,
        unitSold: unitSold,
        sellingPrice: sellingPrice,
        costOfSold: costOfSold,
        profit: profit,
        notes: notes,
      );

      return ClinicInventoryItem.fromJson(response);
    } catch (e) {
      debugPrint('Error selling quantity: $e');
      rethrow;
    }
  }

  // ==================== التقارير ====================

  /// جلب ملخص اليوم
  Future<DailySummary?> getTodaySummary() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('clinic_inventory_daily_summary')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('transaction_date', today)
          .maybeSingle();

      if (response == null) return null;
      return DailySummary.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching today summary: $e');
      return null;
    }
  }

  /// جلب تقرير فترة
  Future<InventoryReportSummary> getReportSummary({
    required DateTime startDate,
    required DateTime endDate,
    required String periodType,
  }) async {
    try {
      final response = await _supabase
          .from('clinic_inventory_daily_summary')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('transaction_date', startDate.toIso8601String().split('T')[0])
          .lte('transaction_date', endDate.toIso8601String().split('T')[0])
          .order('transaction_date', ascending: false);

      final summaries = (response as List)
          .map((json) => DailySummary.fromJson(json))
          .toList();

      return InventoryReportSummary(
        periodType: periodType,
        startDate: startDate,
        endDate: endDate,
        dailySummaries: summaries,
      );
    } catch (e) {
      debugPrint('Error fetching report summary: $e');
      rethrow;
    }
  }

  /// جلب عمليات يوم معين (للتقارير التفصيلية)
  Future<List<InventoryTransaction>> getTransactionsByDate(
      DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('clinic_inventory_transactions')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('transaction_date', dateStr)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => InventoryTransaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions by date: $e');
      return [];
    }
  }

  /// جلب عمليات فترة معينة
  Future<List<InventoryTransaction>> getTransactionsByPeriod(
      DateTime startDate, DateTime endDate) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('clinic_inventory_transactions')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('transaction_date', startStr)
          .lte('transaction_date', endStr)
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => InventoryTransaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions by period: $e');
      return [];
    }
  }

  /// جلب آخر العمليات
  Future<List<InventoryTransaction>> getRecentTransactions({
    int limit = 20,
    String? inventoryId,
  }) async {
    try {
      var query = _supabase
          .from('clinic_inventory_transactions')
          .select()
          .eq('user_id', _currentUserId!);

      if (inventoryId != null) {
        query = query.eq('inventory_id', inventoryId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((json) => InventoryTransaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      rethrow;
    }
  }

  // ==================== حذف وأرشفة ====================

  /// حذف/أرشفة عنصر
  Future<void> archiveItem(String inventoryId) async {
    try {
      await _supabase
          .from('clinic_inventory')
          .update({'is_active': false})
          .eq('id', inventoryId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error archiving item: $e');
      rethrow;
    }
  }

  /// حذف نهائي
  Future<void> deleteItem(String inventoryId) async {
    try {
      await _supabase
          .from('clinic_inventory')
          .delete()
          .eq('id', inventoryId)
          .eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  // ==================== مساعدة ====================

  /// تسجيل عملية
  Future<void> _recordTransaction({
    required String inventoryId,
    required TransactionType type,
    String? productName,
    String? package,
    int boxesAdded = 0,
    double? purchasePricePerBox,
    double quantitySold = 0,
    String? unitSold,
    double? sellingPrice,
    double? costOfSold,
    double? profit,
    String? notes,
  }) async {
    try {
      await _supabase.from('clinic_inventory_transactions').insert({
        'inventory_id': inventoryId,
        'user_id': _currentUserId,
        'transaction_type': type.name,
        'transaction_date': DateTime.now().toIso8601String().split('T')[0],
        'product_name': productName,
        'package': package,
        'boxes_added': boxesAdded,
        'purchase_price_per_box': purchasePricePerBox,
        'total_purchase_cost': boxesAdded * (purchasePricePerBox ?? 0),
        'quantity_sold': quantitySold,
        'unit_sold': unitSold,
        'selling_price': sellingPrice,
        'cost_of_sold': costOfSold,
        'profit': profit,
        'notes': notes,
      });
    } catch (e) {
      debugPrint('Error recording transaction: $e');
      // لا نرمي الخطأ هنا لأن العملية الرئيسية نجحت
    }
  }

  /// جلب إحصائيات سريعة
  Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final items = await getInventoryItems();

      int totalItems = items.length;
      int lowStock = items
          .where((i) =>
              i.stockStatus == StockStatus.low ||
              i.stockStatus == StockStatus.critical)
          .length;
      int outOfStock =
          items.where((i) => i.stockStatus == StockStatus.outOfStock).length;
      int expiringSoon = items
          .where((i) =>
              i.expiryStatus == ExpiryStatus.warning ||
              i.expiryStatus == ExpiryStatus.critical)
          .length;

      final todaySummary = await getTodaySummary();

      return {
        'totalItems': totalItems,
        'lowStock': lowStock,
        'outOfStock': outOfStock,
        'expiringSoon': expiringSoon,
        'todaySales': todaySummary?.totalSales ?? 0,
        'todayProfit': todaySummary?.totalProfit ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching quick stats: $e');
      return {
        'totalItems': 0,
        'lowStock': 0,
        'outOfStock': 0,
        'expiringSoon': 0,
        'todaySales': 0,
        'todayProfit': 0,
      };
    }
  }

  // ==================== Access Code ====================

  /// Get or Generate Clinic Access Code
  Future<String?> getOrGenerateAccessCode() async {
    try {
      final userId = _supabase.auth.currentUser?.id; // Only owner can do this
      if (userId == null) return null;

      // Check existing code
      final data = await _supabase
          .from('users')
          .select('clinic_access_code')
          .eq('id', userId)
          .single();

      if (data['clinic_access_code'] != null) {
        return data['clinic_access_code'] as String;
      }

      // Generate new code (FC-xxxxx)
      // Simple random string generation
      const chars =
          'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, 1, O, 0 to avoid confusion
      final rnd = DateTime.now().millisecondsSinceEpoch;
      final suffix =
          List.generate(5, (index) => chars[(rnd + index * 13) % chars.length])
              .join();
      final code = 'FC-$suffix';

      await _supabase
          .from('users')
          .update({'clinic_access_code': code}).eq('id', userId);

      return code;
    } catch (e) {
      debugPrint('Error managing access code: $e');
      return null;
    }
  }
}

/// Provider للخدمة
final clinicInventoryServiceProvider = Provider<ClinicInventoryService>((ref) {
  return ClinicInventoryService(Supabase.instance.client, ref);
});

/// Provider لإعادة تحميل البيانات
final inventoryRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider لقائمة الجرد
final clinicInventoryListProvider =
    FutureProvider<List<ClinicInventoryItem>>((ref) async {
  ref.watch(inventoryRefreshProvider); // Trigger refresh
  final service = ref.watch(clinicInventoryServiceProvider);
  return service.getInventoryItems();
});

/// Provider للإحصائيات السريعة
final clinicInventoryStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(inventoryRefreshProvider); // Trigger refresh
  final service = ref.watch(clinicInventoryServiceProvider);
  return service.getQuickStats();
});

/// Provider للعمليات الأخيرة
final recentTransactionsProvider =
    FutureProvider<List<InventoryTransaction>>((ref) async {
  ref.watch(inventoryRefreshProvider); // Trigger refresh
  final service = ref.watch(clinicInventoryServiceProvider);
  return service.getRecentTransactions();
});
