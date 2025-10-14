import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobOffersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<JobOffer>> getAllJobOffers() async {
    try {
      final response = await _supabase.rpc('get_all_job_offers');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => JobOffer.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch job offers: $e');
    }
  }

  Future<List<JobOffer>> getMyJobOffers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc('get_my_job_offers', params: {
        'p_user_id': userId,
      });
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => JobOffer.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch my job offers: $e');
    }
  }

  Future<String> createJobOffer({
    required String title,
    required String description,
    required String phone,
  }) async {
    try {
      final response = await _supabase.rpc('create_job_offer', params: {
        'p_title': title,
        'p_description': description,
        'p_phone': phone,
      });
      
      return response as String;
    } catch (e) {
      throw Exception('Failed to create job offer: $e');
    }
  }

  Future<bool> updateJobOffer({
    required String jobId,
    required String title,
    required String description,
    required String phone,
  }) async {
    try {
      await _supabase.rpc('update_job_offer', params: {
        'p_job_id': jobId,
        'p_title': title,
        'p_description': description,
        'p_phone': phone,
      });
      
      return true;
    } catch (e) {
      throw Exception('Failed to update job offer: $e');
    }
  }

  Future<bool> deleteJobOffer(String jobId) async {
    try {
      await _supabase.rpc('delete_job_offer', params: {
        'p_job_id': jobId,
      });
      
      return true;
    } catch (e) {
      throw Exception('Failed to delete job offer: $e');
    }
  }

  Future<void> incrementJobViews(String jobId) async {
    try {
      await _supabase.rpc('increment_job_views', params: {
        'p_job_id': jobId,
      });
    } catch (e) {
      // Silently fail for view increment
    }
  }

  Future<bool> closeJobOffer(String jobId) async {
    try {
      await _supabase.rpc('close_job_offer', params: {
        'p_job_id': jobId,
      });
      
      return true;
    } catch (e) {
      throw Exception('Failed to close job offer: $e');
    }
  }
}
