import 'package:fieldawy_store/features/offers/domain/offer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OffersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Admin: Get all offers
  Future<List<Offer>> adminGetAllOffers() async {
    try {
      // 1. جلب جميع الـ offers
      final offersResponse = await _supabase
          .from('offers')
          .select('''
            id,
            product_id,
            is_ocr,
            user_id,
            price,
            expiration_date,
            description,
            package,
            created_at
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> offersData = offersResponse as List<dynamic>;
      
      if (offersData.isEmpty) {
        return [];
      }

      // 2. جمع product_ids الفريدة
      final productIds = offersData
          .where((o) => o['is_ocr'] == false) // فقط catalog products
          .map((o) => o['product_id'].toString())
          .toSet()
          .toList();

      // 3. جلب الصور من جدول products
      Map<String, String> productImages = {};
      if (productIds.isNotEmpty) {
        try {
          final productsResponse = await _supabase
              .from('products')
              .select('id, image_url')
              .inFilter('id', productIds);

          final List<dynamic> productsData = productsResponse as List<dynamic>;
          for (var product in productsData) {
            productImages[product['id'].toString()] = product['image_url']?.toString() ?? '';
          }
        } catch (e) {
          print('Error fetching product images: $e');
        }
      }

      // 4. جلب الصور من جدول ocr_products (إن وجد)
      final ocrProductIds = offersData
          .where((o) => o['is_ocr'] == true)
          .map((o) => o['product_id'].toString())
          .toSet()
          .toList();

      if (ocrProductIds.isNotEmpty) {
        try {
          final ocrResponse = await _supabase
              .from('ocr_products')
              .select('id, image_url')
              .inFilter('id', ocrProductIds);

          final List<dynamic> ocrData = ocrResponse as List<dynamic>;
          for (var product in ocrData) {
            productImages[product['id'].toString()] = product['image_url']?.toString() ?? '';
          }
        } catch (e) {
          print('Error fetching OCR product images: $e');
        }
      }

      // 5. دمج البيانات
      return offersData.map((json) {
        final offerData = json as Map<String, dynamic>;
        final productId = offerData['product_id'].toString();
        offerData['image_url'] = productImages[productId];
        return Offer.fromJson(offerData);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch all offers: $e');
    }
  }

  // Admin: Delete offer
  Future<bool> adminDeleteOffer(String id) async {
    try {
      await _supabase
          .from('offers')
          .delete()
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to delete offer: $e');
    }
  }

  // Admin: Get offer details with product name
  Future<Offer?> getOfferWithDetails(String id) async {
    try {
      final response = await _supabase
          .from('offers')
          .select('''
            id,
            product_id,
            is_ocr,
            user_id,
            price,
            expiration_date,
            description,
            package,
            created_at
          ''')
          .eq('id', id)
          .single();

      return Offer.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch offer details: $e');
    }
  }

  // Admin: Delete expired offers (for cleanup)
  Future<int> adminDeleteExpiredOffers() async {
    try {
      final response = await _supabase
          .from('offers')
          .delete()
          .lt('expiration_date', DateTime.now().toIso8601String())
          .select();

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to delete expired offers: $e');
    }
  }

  // Admin: Update offer
  Future<bool> adminUpdateOffer({
    required String id,
    required double price,
    required DateTime expirationDate,
    String? description,
    String? package,
  }) async {
    try {
      await _supabase
          .from('offers')
          .update({
            'price': price,
            'expiration_date': expirationDate.toIso8601String(),
            'description': description,
            'package': package,
          })
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to update offer: $e');
    }
  }
}
