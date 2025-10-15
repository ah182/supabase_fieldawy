import 'package:fieldawy_store/features/offers/domain/offer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OffersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Admin: Get all offers
  Future<List<Offer>> adminGetAllOffers() async {
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
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Offer.fromJson(json as Map<String, dynamic>)).toList();
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

      if (response == null) {
        return null;
      }

      return Offer.fromJson(response as Map<String, dynamic>);
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

      if (response == null) {
        return 0;
      }

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
