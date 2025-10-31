import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferencesService {
  static final _supabase = Supabase.instance.client;

  /// Get user notification preferences
  static Future<Map<String, bool>> getPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No preferences found, return defaults (all enabled)
        return {
          'price_action': true,
          'expire_soon': true,
          'offers': true,
          'surgical_tools': true,
          'books': true,
          'courses': true,
          'job_offers': true,
          'vet_supplies': true,
        };
      }

      return {
        'price_action': response['price_action'] ?? true,
        'expire_soon': response['expire_soon'] ?? true,
        'offers': response['offers'] ?? true,
        'surgical_tools': response['surgical_tools'] ?? true,
        'books': response['books'] ?? true,
        'courses': response['courses'] ?? true,
        'job_offers': response['job_offers'] ?? true,
        'vet_supplies': response['vet_supplies'] ?? true,
      };
    } catch (e) {
      print('Error fetching notification preferences: $e');
      rethrow;
    }
  }

  /// Update a specific notification preference
  static Future<void> updatePreference(String type, bool enabled) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if preferences exist
      final existing = await _supabase
          .from('notification_preferences')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Create new preferences
        await _supabase.from('notification_preferences').insert({
          'user_id': userId,
          'price_action': type == 'price_action' ? enabled : true,
          'expire_soon': type == 'expire_soon' ? enabled : true,
          'offers': type == 'offers' ? enabled : true,
          'surgical_tools': type == 'surgical_tools' ? enabled : true,
          'books': type == 'books' ? enabled : true,
          'courses': type == 'courses' ? enabled : true,
          'job_offers': type == 'job_offers' ? enabled : true,
          'vet_supplies': type == 'vet_supplies' ? enabled : true,
        });
      } else {
        // Update existing preferences
        await _supabase
            .from('notification_preferences')
            .update({type: enabled})
            .eq('user_id', userId);
      }
    } catch (e) {
      print('Error updating notification preference: $e');
      rethrow;
    }
  }

  /// Update all preferences at once
  static Future<void> updateAllPreferences({
    required bool priceAction,
    required bool expireSoon,
    required bool offers,
    required bool surgicalTools,
    required bool books,
    required bool courses,
    required bool jobOffers,
    required bool vetSupplies,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('notification_preferences').upsert({
        'user_id': userId,
        'price_action': priceAction,
        'expire_soon': expireSoon,
        'offers': offers,
        'surgical_tools': surgicalTools,
        'books': books,
        'courses': courses,
        'job_offers': jobOffers,
        'vet_supplies': vetSupplies,
      });
    } catch (e) {
      print('Error updating all notification preferences: $e');
      rethrow;
    }
  }

  /// Check if a specific notification type is enabled for the current user
  static Future<bool> isNotificationEnabled(String type) async {
    try {
      final prefs = await getPreferences();
      return prefs[type] ?? true; // Default to enabled if not found
    } catch (e) {
      print('Error checking notification preference: $e');
      return true; // Default to enabled on error
    }
  }
}
