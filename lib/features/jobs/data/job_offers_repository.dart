import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobOffersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  JobOffersRepository(this._cache);

  Future<List<JobOffer>> getAllJobOffers() async {
    // استخدام Cache-First للوظائف (تتغير ببطء)
    return await _cache.cacheFirst<List<JobOffer>>(
      key: 'all_job_offers_v2',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllJobOffers,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => JobOffer.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<JobOffer>> _fetchAllJobOffers() async {
    return await NetworkGuard.execute(() async {
      try {
        // 1. Fetch raw job offers
        final response = await _supabase
            .from('job_offers')
            .select()
            .order('created_at', ascending: false);
        
        final List<dynamic> data = response as List<dynamic>;
        
        // 2. Extract User IDs
        final userIds = data
            .map((json) => json['user_id']?.toString())
            .where((id) => id != null)
            .toSet()
            .toList();
        
        // 3. Fetch User Details from public.users
        Map<String, Map<String, dynamic>> userMap = {};
        if (userIds.isNotEmpty) {
          // Cast to List<Object> to satisfy inFilter
          final usersResponse = await _supabase
              .from('users')
              .select('id, display_name, photo_url')
              .inFilter('id', userIds.cast<Object>());
              
          for (var user in usersResponse) {
            userMap[user['id'].toString()] = user;
          }
        }
        
        // 4. Map to JobOffer with user details
        final jobOffers = data.map((json) {
          final userId = json['user_id']?.toString();
          final userData = userId != null ? userMap[userId] : null;
          
          final flattened = Map<String, dynamic>.from(json);
          if (userData != null) {
            flattened['user_name'] = userData['display_name'];
            flattened['user_photo'] = userData['photo_url'];
          } else {
             flattened['user_name'] = 'مستخدم';
          }
          return JobOffer.fromJson(flattened);
        }).toList();

        final jsonList = jobOffers.map((j) => j.toJson()).toList();
        _cache.set('all_job_offers_v2', jsonList, duration: CacheDurations.long);
        
        return jobOffers;
      } catch (e) {
        throw Exception('Failed to fetch job offers: $e');
      }
    });
  }

  Future<List<JobOffer>> getMyJobOffers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // استخدام Stale-While-Revalidate لوظائف المستخدم
    return await _cache.staleWhileRevalidate<List<JobOffer>>(
      key: 'my_job_offers_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: () => _fetchMyJobOffers(userId),
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => JobOffer.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<JobOffer>> _fetchMyJobOffers(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_my_job_offers', params: {
          'p_user_id': userId,
        });
        
        if (response == null) return [];
        
        final List<dynamic> data = response as List<dynamic>;
        
        // Fetch User Details (Current User)
        Map<String, dynamic>? userData;
        final userResponse = await _supabase
            .from('users')
            .select('display_name, photo_url')
            .eq('id', userId)
            .maybeSingle();
            
        userData = userResponse;

        final jobOffers = data.map((json) {
          final flattened = Map<String, dynamic>.from(json);
          if (userData != null) {
            flattened['user_name'] = userData['display_name'];
            flattened['user_photo'] = userData['photo_url'];
          }
          return JobOffer.fromJson(flattened);
        }).toList();

        final jsonList = jobOffers.map((j) => j.toJson()).toList();
        _cache.set('my_job_offers_$userId', jsonList, duration: CacheDurations.medium);
        return jobOffers;
      } catch (e) {
        throw Exception('Failed to fetch my job offers: $e');
      }
    });
  }

  Future<String> createJobOffer({
    required String title,
    required String description,
    required String phone,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('create_job_offer', params: {
          'p_title': title,
          'p_description': description,
          'p_phone': phone,
        });
        
        // حذف الكاش بعد الإضافة
        _invalidateJobOffersCache();
        
        return response as String;
      } catch (e) {
        throw Exception('Failed to create job offer: $e');
      }
    });
  }

  Future<bool> updateJobOffer({
    required String jobId,
    required String title,
    required String description,
    required String phone,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('update_job_offer', params: {
          'p_job_id': jobId,
          'p_title': title,
          'p_description': description,
          'p_phone': phone,
        });
        
        // حذف الكاش بعد التعديل
        _invalidateJobOffersCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to update job offer: $e');
      }
    });
  }

  Future<bool> deleteJobOffer(String jobId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('delete_job_offer', params: {
          'p_job_id': jobId,
        });
        
        // حذف الكاش بعد الحذف
        _invalidateJobOffersCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to delete job offer: $e');
      }
    });
  }

  /// حذف كاش الوظائف
  void _invalidateJobOffersCache() {
    _cache.invalidate('all_job_offers_v2');
    _cache.invalidateWithPrefix('my_job_offers_');
    print('🧹 Job offers cache invalidated');
  }

  /// Increment job views - exactly like courses/books
  Future<void> incrementJobViews(String jobId) async {
    try {
      await NetworkGuard.execute(() async {
        await _supabase.rpc('increment_job_views', params: {
          'p_job_id': jobId,
        });
      });
    } catch (e) {
      // Silent fail for views - exactly like courses/books
      print('Failed to increment job views: $e');
    }
  }

  Future<bool> closeJobOffer(String jobId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('close_job_offer', params: {
          'p_job_id': jobId,
        });
        
        // حذف الكاش بعد الإغلاق
        _invalidateJobOffersCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to close job offer: $e');
      }
    });
  }
  
  // ===================================================================
  // ADMIN METHODS
  // ===================================================================
  
  /// Admin: Get all job offers
  Future<List<JobOffer>> adminGetAllJobOffers() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase
            .from('job_offers')
            .select()
            .order('created_at', ascending: false);
        
        return (response as List<dynamic>)
            .map((json) => JobOffer.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw Exception('Failed to load all job offers: $e');
      }
    });
  }

  /// Admin: Delete any job offer
  Future<bool> adminDeleteJobOffer(String jobId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.from('job_offers').delete().eq('id', jobId);
        
        // حذف الكاش
        _invalidateJobOffersCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to delete job offer: $e');
      }
    });
  }
   Future<bool> adminUpdateJobOffer({
    required String jobId,
    required String title,
    required String phone,
    required String description,
    required String status,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.from('job_offers').update({
          'title': title,
          'phone': phone,
          'description': description,
          'status': status,
        }).eq('id', jobId);

        // حذف الكاش
        _invalidateJobOffersCache();

        return true;
      } catch (e) {
        throw Exception('Failed to update job offer: $e');
      }
    });
  }

}

// Provider
final jobOffersRepositoryProvider = Provider<JobOffersRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return JobOffersRepository(cache);
});
