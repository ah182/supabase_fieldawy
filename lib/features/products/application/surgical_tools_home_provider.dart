import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مزود يعرض جميع الأدوات الجراحية من جميع الموزعين
final surgicalToolsHomeProvider = FutureProvider<List<ProductModel>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // جلب جميع الأدوات الجراحية من جميع الموزعين
  final rows = await supabase
      .from('distributor_surgical_tools')
      .select('''
        id,
        description,
        price,
        status,
        distributor_name,
        created_at,
        views,
        surgical_tools (
          id,
          tool_name,
          company,
          image_url
        )
      ''')
      .order('created_at', ascending: false);

  // تحويل البيانات إلى ProductModel
  final tools = <ProductModel>[];
  for (final row in rows) {
    final surgicalTool = row['surgical_tools'] as Map<String, dynamic>?;
    if (surgicalTool != null) {
      tools.add(ProductModel(
        id: row['id']?.toString() ?? '',
        name: surgicalTool['tool_name']?.toString() ?? '',
        description: row['description']?.toString() ?? '',
        activePrinciple: row['status']?.toString(), // نستخدم status كـ subtitle
        company: surgicalTool['company']?.toString(),
        action: '',
        package: '',
        imageUrl: (surgicalTool['image_url']?.toString() ?? '').startsWith('http')
            ? surgicalTool['image_url'].toString()
            : '',
        price: (row['price'] as num?)?.toDouble(),
        distributorId: row['distributor_name']?.toString(), // اسم الموزع
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString())
            : null,
        availablePackages: [],
        selectedPackage: null,
        isFavorite: false,
        oldPrice: null,
        priceUpdatedAt: null,
        views: (row['views'] as int?) ?? 0,
        surgicalToolId: surgicalTool['id']?.toString(),
      ));
    }
  }

  return tools;
});
