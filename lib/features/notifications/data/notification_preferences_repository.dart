import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/services/subscription_cache_service.dart';

class NotificationPreferencesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  NotificationPreferencesRepository(this._cache);

  /// Get user notification preferences (مع الكاش)
  Future<Map<String, bool>> getPreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // استخدام Cache-First (البيانات نادرة التغيير)
    return await _cache.cacheFirst<Map<String, bool>>(
      key: 'notification_preferences_$userId',
      duration: CacheDurations.medium, // 1 ساعة
      fetchFromNetwork: () => _fetchPreferences(userId),
      fromCache: (data) {
        // Convert cached data to Map<String, bool>
        final map = Map<String, dynamic>.from(data);
        return map.map((key, value) => MapEntry(key, value as bool));
      },
    );
  }

  Future<Map<String, bool>> _fetchPreferences(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase
            .from('notification_preferences')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        final Map<String, bool> result = response == null
            ? _getDefaultPreferences()
            : {
                'price_action': (response['price_action'] ?? true) as bool,
                'expire_soon': (response['expire_soon'] ?? true) as bool,
                'offers': (response['offers'] ?? true) as bool,
                'surgical_tools': (response['surgical_tools'] ?? true) as bool,
                'books': (response['books'] ?? true) as bool,
                'courses': (response['courses'] ?? true) as bool,
                'job_offers': (response['job_offers'] ?? true) as bool,
                'vet_supplies': (response['vet_supplies'] ?? true) as bool,
              };

        // Cache the result
        _cache.set('notification_preferences_$userId', result, duration: CacheDurations.medium);

        return result;
      } catch (e) {
        print('Error fetching notification preferences: $e');
        rethrow;
      }
    });
  }

  Map<String, bool> _getDefaultPreferences() {
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

  /// Update a specific notification preference
  Future<void> updatePreference(String type, bool enabled) async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) throw Exception('User not authenticated');

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
              .update({type: enabled}).eq('user_id', userId);
        }

        // Invalidate cache after update
        invalidateCache();
      } catch (e) {
        print('Error updating notification preference: $e');
        rethrow;
      }
    });
  }

  /// Get subscribed distributors with details (مع الكاش)
  Future<List<DistributorModel>> getSubscribedDistributors() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Cache-First (البيانات نادرة التغيير)
    return await _cache.cacheFirst<List<DistributorModel>>(
      key: 'subscribed_distributors_$userId',
      duration: CacheDurations.short, // 15 دقيقة (قد يضيف/يحذف موزعين)
      fetchFromNetwork: () => _fetchSubscribedDistributors(),
      fromCache: (data) {
        // Convert cached list to DistributorModel list
        final list = data as List;
        return list
            .map((json) => _distributorFromJson(Map<String, dynamic>.from(json)))
            .toList();
      },
    );
  }

  Future<List<DistributorModel>> _fetchSubscribedDistributors() async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return [];

        // Get distributor IDs from Hive
        final distributorIds = await SubscriptionCacheService.getSubscriptions();
        final uniqueDistributorIds = distributorIds.toSet().toList();

        print('📋 Loading ${uniqueDistributorIds.length} subscribed distributors');

        if (uniqueDistributorIds.isEmpty) return [];

        // Fetch all distributors in one query
        final usersResponse = await _supabase
            .from('users')
            .select()
            .inFilter('id', uniqueDistributorIds);

        final distributors = <DistributorModel>[];

        for (final userRow in (usersResponse as List)) {
          try {
            final id = userRow['id'] as String;
            final displayName = userRow['display_name'] as String? ?? 'موزع';
            final email = userRow['email'] as String?;
            final photoUrl = userRow['photo_url'] as String?;
            final whatsappNumber = userRow['whatsapp_number'] as String?;
            final companyName = userRow['company_name'] as String?;
            final distributorType = userRow['distributor_type'] as String? ??
                (companyName != null ? 'company' : 'individual');

            List<String> governorates = [];
            if (userRow['governorates'] is List) {
              governorates = (userRow['governorates'] as List).cast<String>();
            }

            List<String> centers = [];
            if (userRow['centers'] is List) {
              centers = (userRow['centers'] as List).cast<String>();
            }

            final distributor = DistributorModel(
              id: id,
              displayName: displayName,
              email: email,
              photoURL: photoUrl,
              governorates: governorates,
              centers: centers,
              productCount: 0,
              distributorType: distributorType,
              whatsappNumber: whatsappNumber,
              companyName: companyName,
            );

            distributors.add(distributor);
          } catch (e) {
            print('❌ Error parsing user row: $e');
            continue;
          }
        }

        // Cache the result (as JSON list)
        final jsonList = distributors.map((d) => _distributorToJson(d)).toList();
        _cache.set('subscribed_distributors_$userId', jsonList, 
                   duration: CacheDurations.short);

        return distributors;
      } catch (e) {
        print('❌ Error fetching subscribed distributors: $e');
        return [];
      }
    });
  }

  /// Invalidate all notification caches
  void invalidateCache() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _cache.invalidate('notification_preferences_$userId');
      _cache.invalidate('subscribed_distributors_$userId');
    }
    print('🧹 Notification preferences cache invalidated');
  }

  /// Convert DistributorModel to JSON
  Map<String, dynamic> _distributorToJson(DistributorModel distributor) {
    return {
      'id': distributor.id,
      'displayName': distributor.displayName,
      'email': distributor.email,
      'photoURL': distributor.photoURL,
      'governorates': distributor.governorates,
      'centers': distributor.centers,
      'productCount': distributor.productCount,
      'distributorType': distributor.distributorType,
      'whatsappNumber': distributor.whatsappNumber,
      'companyName': distributor.companyName,
    };
  }

  /// Convert JSON to DistributorModel
  DistributorModel _distributorFromJson(Map<String, dynamic> json) {
    return DistributorModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'موزع',
      email: json['email'] as String?,
      photoURL: json['photoURL'] as String?,
      governorates: json['governorates'] != null
          ? List<String>.from(json['governorates'] as List)
          : [],
      centers: json['centers'] != null
          ? List<String>.from(json['centers'] as List)
          : [],
      productCount: json['productCount'] as int? ?? 0,
      distributorType: json['distributorType'] as String? ?? 'individual',
      whatsappNumber: json['whatsappNumber'] as String?,
      companyName: json['companyName'] as String?,
    );
  }
}

// Provider
final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return NotificationPreferencesRepository(cache);
});
