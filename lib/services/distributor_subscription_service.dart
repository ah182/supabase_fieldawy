import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_cache_service.dart';

/// Service for managing user subscriptions to distributors
/// Users can subscribe to specific distributors to receive all their notifications
/// even if general notification settings are disabled
class DistributorSubscriptionService {
  static final _supabase = Supabase.instance.client;

  /// Check if current user is subscribed to a distributor (from Hive)
  static Future<bool> isSubscribed(String distributorId) async {
    try {
      return await SubscriptionCacheService.isSubscribedCached(distributorId);
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  /// Subscribe to a distributor (save to DB + Hive + Increment server count)
  static Future<bool> subscribe(String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // 1. Insert into Supabase table
      await _supabase.from('distributor_subscriptions').insert({
        'user_id': userId,
        'distributor_id': distributorId,
      });

      // 2. Update local cache
      await SubscriptionCacheService.addSubscription(distributorId);
      
      // 3. Increment counter (RPC)
      try {
        await _supabase.rpc('increment_subscribers', params: {'user_id': distributorId});
      } catch (e) {
        // Fallback: Manual update
        try {
          final user = await _supabase.from('users').select('subscribers_count').eq('id', distributorId).single();
          final currentCount = (user['subscribers_count'] as int?) ?? 0;
          await _supabase.from('users').update({'subscribers_count': currentCount + 1}).eq('id', distributorId);
        } catch (_) {}
      }
      
      return true;
    } catch (e) {
      print('Error subscribing to distributor: $e');
      // If error is duplicate key (already subscribed), treat as success for UI
      if (e.toString().contains('23505') || e.toString().contains('unique constraint')) {
         await SubscriptionCacheService.addSubscription(distributorId);
         return true;
      }
      return false;
    }
  }

  /// Unsubscribe from a distributor (remove from DB + Hive + Decrement server count)
  static Future<bool> unsubscribe(String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // 1. Remove from Supabase table
      await _supabase.from('distributor_subscriptions').delete().match({
        'user_id': userId,
        'distributor_id': distributorId,
      });

      // 2. Update local cache
      await SubscriptionCacheService.removeSubscription(distributorId);
      
      // 3. Decrement counter (RPC)
      try {
        await _supabase.rpc('decrement_subscribers', params: {'user_id': distributorId});
      } catch (e) {
        // Fallback
        try {
          final user = await _supabase.from('users').select('subscribers_count').eq('id', distributorId).single();
          final currentCount = (user['subscribers_count'] as int?) ?? 0;
          final newCount = (currentCount - 1) < 0 ? 0 : (currentCount - 1);
          await _supabase.from('users').update({'subscribers_count': newCount}).eq('id', distributorId);
        } catch (_) {}
      }
      
      return true;
    } catch (e) {
      print('Error unsubscribing from distributor: $e');
      return false;
    }
  }

  /// Sync local cache with Supabase (Call this on app start or screen load)
  static Future<void> syncSubscriptions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('distributor_subscriptions')
          .select('distributor_id')
          .eq('user_id', userId);
      
      final List<String> serverIds = (response as List)
          .map((row) => row['distributor_id'] as String)
          .toList();
      
      await SubscriptionCacheService.syncWithServer(serverIds);
    } catch (e) {
      print('Error syncing subscriptions: $e');
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

  /// Get all subscribed distributors for current user (from Hive)
  static Future<List<String>> getSubscribedDistributorIds() async {
    try {
      return await SubscriptionCacheService.getSubscriptions();
    } catch (e) {
      print('Error fetching subscribed distributors: $e');
      return [];
    }
  }

  /// Get detailed list of subscribed distributors from Hive cache
  static Future<List<Map<String, dynamic>>> getSubscribedDistributors() async {
    try {
      // Get subscribed distributor IDs from Hive cache
      final distributorIds = await SubscriptionCacheService.getSubscriptions();
      
      if (distributorIds.isEmpty) return [];

      // Get user details for all distributors in parallel
      final futures = distributorIds.map((distributorId) async {
        try {
          final userResponse = await _supabase
              .from('users')
              .select('display_name')
              .eq('id', distributorId)
              .maybeSingle();

          return {
            'distributor_id': distributorId,
            'distributor_name': userResponse?['display_name'] ?? 'موزع',
            'created_at': null, // No creation date in Hive
          };
        } catch (e) {
          // If we can't get user details, add with default name
          print('Error fetching user details for $distributorId: $e');
          return {
            'distributor_id': distributorId,
            'distributor_name': 'موزع',
            'created_at': null,
          };
        }
      }).toList();

      final results = await Future.wait(futures);
      return results;
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

  /// Get subscription count for statistics (from Hive)
  static Future<int> getSubscriptionCount() async {
    try {
      final subscriptions = await SubscriptionCacheService.getSubscriptions();
      return subscriptions.length;
    } catch (e) {
      print('Error getting subscription count: $e');
      return 0;
    }
  }
}
