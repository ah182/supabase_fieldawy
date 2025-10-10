import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_cache_service.dart';

/// Service for managing user subscriptions to distributors
/// Users can subscribe to specific distributors to receive all their notifications
/// even if general notification settings are disabled
class DistributorSubscriptionService {
  static final _supabase = Supabase.instance.client;

  /// Check if current user is subscribed to a distributor
  static Future<bool> isSubscribed(String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('distributor_subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('distributor_id', distributorId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  /// Subscribe to a distributor
  static Future<bool> subscribe(String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('distributor_subscriptions').insert({
        'user_id': userId,
        'distributor_id': distributorId,
      });

      // Update local cache
      await SubscriptionCacheService.addSubscription(distributorId);

      return true;
    } catch (e) {
      print('Error subscribing to distributor: $e');
      return false;
    }
  }

  /// Unsubscribe from a distributor
  static Future<bool> unsubscribe(String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('distributor_subscriptions')
          .delete()
          .eq('user_id', userId)
          .eq('distributor_id', distributorId);

      // Update local cache
      await SubscriptionCacheService.removeSubscription(distributorId);

      return true;
    } catch (e) {
      print('Error unsubscribing from distributor: $e');
      return false;
    }
  }

  /// Toggle subscription (subscribe if not subscribed, unsubscribe if subscribed)
  static Future<bool> toggleSubscription(String distributorId) async {
    try {
      final isCurrentlySubscribed = await isSubscribed(distributorId);
      
      if (isCurrentlySubscribed) {
        return await unsubscribe(distributorId);
      } else {
        return await subscribe(distributorId);
      }
    } catch (e) {
      print('Error toggling subscription: $e');
      return false;
    }
  }

  /// Get all subscribed distributors for current user
  static Future<List<String>> getSubscribedDistributorIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('distributor_subscriptions')
          .select('distributor_id')
          .eq('user_id', userId);

      final distributorIds = (response as List)
          .map((item) => item['distributor_id'] as String)
          .toList();
      
      // Sync with local cache
      await SubscriptionCacheService.syncWithServer(distributorIds);
      
      return distributorIds;
    } catch (e) {
      print('Error fetching subscribed distributors: $e');
      return [];
    }
  }

  /// Get detailed list of subscribed distributors
  static Future<List<Map<String, dynamic>>> getSubscribedDistributors() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('distributor_subscriptions')
          .select('distributor_id, created_at, users!distributor_id(full_name, username)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final user = item['users'];
        return {
          'distributor_id': item['distributor_id'],
          'distributor_name': user?['full_name'] ?? user?['username'] ?? 'موزع',
          'created_at': item['created_at'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching subscribed distributors details: $e');
      return [];
    }
  }

  /// Check if user should receive notification from this distributor
  /// Priority: Subscribed distributor > General settings
  static Future<bool> shouldReceiveNotification({
    required String distributorId,
    required String notificationType,
  }) async {
    try {
      // Check if subscribed to this distributor
      final isSubscribedToDistributor = await isSubscribed(distributorId);
      
      if (isSubscribedToDistributor) {
        // If subscribed, always receive notifications from this distributor
        return true;
      }
      
      // If not subscribed, check general notification preferences
      // This will be handled by NotificationPreferencesService
      return false;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  /// Get subscription count for statistics
  static Future<int> getSubscriptionCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('distributor_subscriptions')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting subscription count: $e');
      return 0;
    }
  }
}
