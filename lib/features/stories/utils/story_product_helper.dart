import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:fieldawy_store/features/books/presentation/screens/book_details_screen.dart';
import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/course_details_screen.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/product_dialogs.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryProductHelper {
  static Future<Map<String, dynamic>?> fetchProductDetails(String linkId) async {
    final supabase = Supabase.instance.client;

    try {
      if (linkId.startsWith('reg_')) {
        final id = linkId.replaceFirst('reg_', '');
        final response = await supabase
            .from('distributor_products')
            .select('id, price, package, distributor_id, distributor_name, products(name, image_url, description, active_principle, company)')
            .eq('id', id)
            .maybeSingle();
        return response != null ? {...response, 'type': 'regular'} : null;
      } 
      else if (linkId.startsWith('ocr_')) {
        final id = linkId.replaceFirst('ocr_', '');
        final response = await supabase
            .from('distributor_ocr_products')
            .select('id, price, distributor_id, distributor_name, ocr_products(product_name, image_url, active_principle, product_company, package)')
            .eq('id', id)
            .maybeSingle();
        return response != null ? {...response, 'type': 'ocr'} : null;
      }
      else if (linkId.startsWith('tool_')) {
        final id = linkId.replaceFirst('tool_', '');
        final response = await supabase
            .from('distributor_surgical_tools')
            .select('*, surgical_tools(tool_name, image_url)')
            .eq('id', id)
            .maybeSingle();
        
        if (response != null && response['surgical_tools'] != null) {
          final toolData = response['surgical_tools'] as Map<String, dynamic>;
          response['image_url'] = toolData['image_url'];
          response['tool_name'] = toolData['tool_name'];
        }
        return response != null ? {...response, 'type': 'tool'} : null;
      }
      else if (linkId.startsWith('supply_')) {
        final id = linkId.replaceFirst('supply_', '');
        final response = await supabase
            .from('vet_supplies')
            .select('*')
            .eq('id', id)
            .maybeSingle();
        return response != null ? {...response, 'type': 'supply'} : null;
      }
      else if (linkId.startsWith('book_')) {
        final id = linkId.replaceFirst('book_', '');
        final response = await supabase
            .from('vet_books')
            .select('*')
            .eq('id', id)
            .maybeSingle();
        
        if (response != null) {
          response['image_url'] = response['image_url'] ?? response['cover_url'];
          response['title'] = response['name']; 
        }
        return response != null ? {...response, 'type': 'book'} : null;
      }
      else if (linkId.startsWith('course_')) {
        final id = linkId.replaceFirst('course_', '');
        final response = await supabase
            .from('vet_courses')
            .select('*')
            .eq('id', id)
            .maybeSingle();
        
        if (response != null) {
          response['image_url'] = response['image_url'] ?? response['poster_url'];
        }
        return response != null ? {...response, 'type': 'course'} : null;
      }
      else if (linkId.startsWith('offer_')) {
        final id = linkId.replaceFirst('offer_', '');
        // 1. Fetch offer without user join to avoid FK error
        final response = await supabase
            .from('offers')
            .select('*') 
            .eq('id', id)
            .maybeSingle();
            
        if (response != null) {
          // 2. Manual fetch for user name
          try {
            final userId = response['user_id'];
            if (userId != null) {
              final userResponse = await supabase
                  .from('users')
                  .select('display_name')
                  .eq('id', userId) 
                  .maybeSingle();
              
              if (userResponse != null) {
                response['distributor_name'] = userResponse['display_name'];
              }
            }
          } catch (e) {
            debugPrint('Error fetching offer distributor name: $e');
          }

          final isOcr = response['is_ocr'] as bool? ?? false;
          final productId = response['product_id'];
          
          if (isOcr) {
             final p = await supabase.from('ocr_products').select('product_name, image_url, active_principle, product_company').eq('id', productId).maybeSingle();
             if (p != null) {
               response['title'] = p['product_name'];
               response['image_url'] = p['image_url'];
               response['active_principle'] = p['active_principle'];
               response['company'] = p['product_company'];
             }
          } else {
             final p = await supabase.from('products').select('name, image_url, active_principle, company').eq('id', productId).maybeSingle();
             if (p != null) {
               response['title'] = p['name'];
               response['image_url'] = p['image_url'];
               response['active_principle'] = p['active_principle'];
               response['company'] = p['company'];
             }
          }
        }
        return response != null ? {...response, 'type': 'offer'} : null;
      }
      // Fallback for legacy IDs
      else {
        final response = await supabase
            .from('distributor_products')
            .select('id, price, package, distributor_id, distributor_name, products(name, image_url, description, active_principle, company)')
            .eq('id', linkId)
            .maybeSingle();
        return response != null ? {...response, 'type': 'regular'} : null;
      }
    } catch (e) {
      debugPrint('Error fetching story product details: $e');
      return null;
    }
  }

  static Future<void> openProductDialog(BuildContext context, Map<String, dynamic> data) async {
    final type = data['type'];

    switch (type) {
      case 'regular':
        final productInfo = data['products'] as Map<String, dynamic>;
        final product = ProductModel(
          id: data['id'],
          name: productInfo['name'] ?? '',
          description: productInfo['description'] ?? '',
          activePrinciple: productInfo['active_principle'],
          company: productInfo['company'],
          action: null,
          package: data['package'],
          imageUrl: productInfo['image_url'] ?? '',
          price: data['price'],
          distributorId: data['distributor_name'] ?? 'Distributor',
          distributorUuid: data['distributor_id'],
          createdAt: DateTime.now(),
          selectedPackage: data['package'],
          isFavorite: false,
          availablePackages: [data['package'] ?? ''],
        );
        await showProductDialog(context, product);
        break;

      case 'ocr':
        final ocrInfo = data['ocr_products'] as Map<String, dynamic>;
        final product = ProductModel(
          id: 'ocr_${data['id']}',
          name: ocrInfo['product_name'] ?? '',
          description: '',
          activePrinciple: ocrInfo['active_principle'],
          company: ocrInfo['product_company'],
          action: null,
          package: ocrInfo['package'],
          imageUrl: ocrInfo['image_url'] ?? '',
          price: data['price'],
          distributorId: data['distributor_name'] ?? 'Distributor',
          distributorUuid: data['distributor_id'],
          createdAt: DateTime.now(),
          selectedPackage: ocrInfo['package'],
          isFavorite: false,
          availablePackages: [ocrInfo['package'] ?? ''],
        );
        await showProductDialog(context, product);
        break;

      case 'tool':
        final tool = ProductModel(
          id: data['id'].toString(),
          name: data['tool_name'] ?? '',
          description: data['description'],
          activePrinciple: data['status'], 
          company: data['company'],
          action: null,
          package: null,
          imageUrl: data['image_url'] ?? '',
          price: (data['price'] as num?)?.toDouble(),
          distributorId: data['distributor_name'],
          distributorUuid: data['distributor_id']?.toString(),
          createdAt: DateTime.now(),
          isFavorite: false,
          availablePackages: const [],
        );
        await showSurgicalToolDialog(context, tool);
        break;

      case 'supply':
        final supply = VetSupply.fromJson(data);
        await showVetSupplyDialog(context, supply);
        break;

      case 'book':
        data['description'] ??= '';
        data['phone'] ??= '';
        data['updated_at'] ??= DateTime.now().toIso8601String();
        data['created_at'] ??= DateTime.now().toIso8601String();
        data['views'] ??= 0;
        
        final book = Book.fromJson(data);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailsScreen(book: book)),
        );
        break;

      case 'course':
        data['description'] ??= '';
        data['phone'] ??= '';
        data['updated_at'] ??= DateTime.now().toIso8601String();
        data['created_at'] ??= DateTime.now().toIso8601String();
        data['views'] ??= 0;

        final course = Course.fromJson(data);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CourseDetailsScreen(course: course)),
        );
        break;

      case 'offer':
        final offerProduct = ProductModel(
          id: data['id'].toString(),
          name: data['title'] ?? '', // Offer title
          description: data['description'],
          activePrinciple: data['active_principle'],
          company: data['company'],
          action: null,
          package: data['package'],
          imageUrl: data['image_url'] ?? '',
          price: (data['price'] as num?)?.toDouble(),
          distributorId: data['distributor_name'] ?? 'Distributor', // Use fetched name
          distributorUuid: data['user_id']?.toString(), // user_id is the distributor ID
          createdAt: DateTime.parse(data['created_at']),
          isFavorite: false,
          availablePackages: [data['package'] ?? ''],
        );
        
        final expirationDate = data['expiration_date'] != null 
            ? DateTime.parse(data['expiration_date']) 
            : null;
            
        await showOfferProductDialog(context, offerProduct, expirationDate: expirationDate);
        break;
    }
  }
}