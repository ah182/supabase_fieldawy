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
        print('📦 Opening Hive box: $_boxName');
        await Hive.openBox(_boxName);
      }
    } catch (e) {
      print('❌ Error initializing subscription cache: $e');
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
      // Force flush to disk to be safe
      await box.flush();
      print('💾 Saved ${uniqueIds.length} subscriptions: $uniqueIds');
    } catch (e) {
      print('❌ Error saving subscriptions to cache: $e');
    }
  }
  
  /// Get subscribed distributor IDs from cache
  static Future<List<String>> getSubscriptions() async {
    try {
      await init();
      final box = Hive.box(_boxName);
      final data = box.get(_subscriptionsKey);
      
      if (data != null) {
        // Handle different potential types stored in Hive
        List<String> subscriptions = [];
        if (data is List) {
          subscriptions = data.map((e) => e.toString()).toList();
        }
        
        // Remove duplicates
        final uniqueSubscriptions = subscriptions.toSet().toList();
        print('📖 Read ${uniqueSubscriptions.length} subscriptions: $uniqueSubscriptions');
        return uniqueSubscriptions;
      }
      print('📖 No subscriptions found in cache (Key: $_subscriptionsKey)');
      return [];
    } catch (e) {
      print('❌ Error getting subscriptions from cache: $e');
      return [];
    }
  }
  
  /// Check if subscribed to a specific distributor (from cache)
  static Future<bool> isSubscribedCached(String distributorId) async {
    try {
      final subscriptions = await getSubscriptions();
      final isSubscribed = subscriptions.contains(distributorId);
      print('🔍 Checking subscription for $distributorId: $isSubscribed');
      return isSubscribed;
    } catch (e) {
      print('❌ Error checking subscription in cache: $e');
      return false;
    }
  }
  
  /// Add a distributor to cache
  static Future<void> addSubscription(String distributorId) async {
    try {
      print('➕ Adding subscription: $distributorId');
      final current = await getSubscriptions();
      if (!current.contains(distributorId)) {
        // Create a new list to avoid modifying the reference if it came from Hive directly
        final newList = List<String>.from(current)..add(distributorId);
        await saveSubscriptions(newList);
        print('✅ Added subscription successfully');
      } else {
        print('ℹ️ Distributor $distributorId already subscribed');
      }
    } catch (e) {
      print('❌ Error adding subscription to cache: $e');
    }
  }
  
  /// Remove a distributor from cache
  static Future<void> removeSubscription(String distributorId) async {
    try {
      print('➖ Removing subscription: $distributorId');
      final current = await getSubscriptions();
      if (current.contains(distributorId)) {
        final newList = List<String>.from(current)..remove(distributorId);
        await saveSubscriptions(newList);
        print('✅ Removed subscription successfully');
      } else {
        print('ℹ️ Distributor $distributorId was not subscribed');
      }
    } catch (e) {
      print('❌ Error removing subscription from cache: $e');
    }
  }
  
  /// Clear all cached subscriptions
  static Future<void> clearCache() async {
    try {
      await init();
      final box = Hive.box(_boxName);
      await box.clear();
      print('🧹 Cleared subscription cache');
    } catch (e) {
      print('❌ Error clearing subscription cache: $e');
    }
  }
  
  /// Sync cache with Supabase (refresh from server)
  static Future<void> syncWithServer(List<String> serverDistributorIds) async {
    try {
      await saveSubscriptions(serverDistributorIds);
      print('🔄 Synced ${serverDistributorIds.length} subscriptions with cache');
    } catch (e) {
      print('❌ Error syncing with server: $e');
    }
  }
}
