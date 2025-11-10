import 'package:hive_flutter/hive_flutter.dart';

/// Service for caching distributor subscriptions locally using Hive
/// This allows background notifications to check subscriptions without Supabase auth
class SubscriptionCacheService {
  static const String _boxName = 'distributor_subscriptions_cache';
  static const String _subscriptionsKey = 'subscribed_distributor_ids';
  
  /// Initialize Hive box for subscriptions cache
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox(_boxName);
      }
    } catch (e) {
      print('Error initializing subscription cache: $e');
    }
  }
  
  /// Save subscribed distributor IDs to cache
  static Future<void> saveSubscriptions(List<String> distributorIds) async {
    try {
      await init();
      final box = Hive.box(_boxName);
      // Remove duplicates before saving
      final uniqueIds = distributorIds.toSet().toList();
      await box.put(_subscriptionsKey, uniqueIds);
      print('✅ Saved ${uniqueIds.length} unique subscriptions to cache');
    } catch (e) {
      print('Error saving subscriptions to cache: $e');
    }
  }
  
  /// Get subscribed distributor IDs from cache
  static Future<List<String>> getSubscriptions() async {
    try {
      await init();
      final box = Hive.box(_boxName);
      final data = box.get(_subscriptionsKey);
      
      if (data is List) {
        final subscriptions = List<String>.from(data);
        // Remove duplicates
        final uniqueSubscriptions = subscriptions.toSet().toList();
        print('📖 Read ${uniqueSubscriptions.length} unique subscriptions from cache');
        return uniqueSubscriptions;
      }
      print('📖 No subscriptions found in cache');
      return [];
    } catch (e) {
      print('Error getting subscriptions from cache: $e');
      return [];
    }
  }
  
  /// Check if subscribed to a specific distributor (from cache)
  static Future<bool> isSubscribedCached(String distributorId) async {
    try {
      final subscriptions = await getSubscriptions();
      return subscriptions.contains(distributorId);
    } catch (e) {
      print('Error checking subscription in cache: $e');
      return false;
    }
  }
  
  /// Add a distributor to cache
  static Future<void> addSubscription(String distributorId) async {
    try {
      final current = await getSubscriptions();
      if (!current.contains(distributorId)) {
        current.add(distributorId);
        await saveSubscriptions(current);
        print('✅ Added subscription for distributor: $distributorId');
      } else {
        print('ℹ️ Distributor $distributorId already subscribed');
      }
    } catch (e) {
      print('Error adding subscription to cache: $e');
    }
  }
  
  /// Remove a distributor from cache
  static Future<void> removeSubscription(String distributorId) async {
    try {
      final current = await getSubscriptions();
      if (current.contains(distributorId)) {
        current.remove(distributorId);
        await saveSubscriptions(current);
      }
    } catch (e) {
      print('Error removing subscription from cache: $e');
    }
  }
  
  /// Clear all cached subscriptions
  static Future<void> clearCache() async {
    try {
      await init();
      final box = Hive.box(_boxName);
      await box.clear();
      print('✅ Cleared subscription cache');
    } catch (e) {
      print('Error clearing subscription cache: $e');
    }
  }
  
  /// Sync cache with Supabase (refresh from server)
  static Future<void> syncWithServer(List<String> serverDistributorIds) async {
    try {
      await saveSubscriptions(serverDistributorIds);
      print('✅ Synced ${serverDistributorIds.length} subscriptions with cache');
    } catch (e) {
      print('Error syncing with server: $e');
    }
  }
}
