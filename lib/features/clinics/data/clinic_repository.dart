import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/clinic_model.dart';

class ClinicRepository {
  final SupabaseClient _client;

  ClinicRepository({required SupabaseClient client}) : _client = client;

  // New method to get all clinics with doctor info from the view
  Future<List<ClinicWithDoctorInfo>> getAllClinicsWithDoctorInfo() async {
    try {
      final response = await _client
          .from('clinics_with_doctor_info')
          .select()
          .order('created_at', ascending: false);

      final clinics = (response as List)
          .map((json) => ClinicWithDoctorInfo.fromMap(json))
          .toList();
      
      return clinics;
    } catch (e, stackTrace) {
      print('❌ Error fetching clinics with doctor info: $e');
      print('📚 Stack trace: $stackTrace');
      return [];
    }
  }

  // Get all clinics (original method, can be kept for other purposes if needed)
  Future<List<ClinicModel>> getAllClinics() async {
    try {
      final response = await _client
          .from('clinics')
          .select()
          .order('created_at', ascending: false);

      final clinics = (response as List)
          .map((json) => ClinicModel.fromMap(json))
          .toList();
      
      return clinics;
    } catch (e, stackTrace) {
      print('❌ Error fetching all clinics: $e');
      print('📚 Stack trace: $stackTrace');
      return [];
    }
  }

  // Get clinic by user ID
  Future<ClinicModel?> getClinicByUserId(String userId) async {
    try {
      final response = await _client
          .from('clinics')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return ClinicModel.fromMap(response);
    } catch (e) {
      print('Error fetching clinic by user ID: $e');
      return null;
    }
  }

  // Create or update clinic (upsert) using a dedicated RPC function
  Future<bool> upsertClinic({
    required String userId,
    required String clinicName,
    required double latitude,
    required double longitude,
    String? address,
    String? phoneNumber,
  }) async {
    try {
      await _client.rpc('upsert_clinic', params: {
        'p_user_id': userId,
        'p_clinic_name': clinicName,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_address': address,
        'p_phone_number': phoneNumber,
      });
      return true;
    } catch (e) {
      print('❌ Error upserting clinic: $e');
      return false;
    }
  }

  // Delete clinic
  Future<bool> deleteClinic(String userId) async {
    try {
      await _client.from('clinics').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error deleting clinic: $e');
      return false;
    }
  }

  // Get nearby clinics efficiently using PostGIS RPC function
  Future<List<ClinicModel>> getNearbyClinics({
    required double latitude,
    required double longitude,
    double radiusInKm = 50.0,
  }) async {
    try {
      final response = await _client.rpc('get_nearby_clinics', params: {
        'p_lat': latitude,
        'p_long': longitude,
        'p_radius_meters': radiusInKm * 1000, // Convert km to meters
      });

      final clinics = (response as List)
          .map((json) => ClinicModel.fromMap(json))
          .toList();

      return clinics;
    } catch (e) {
      print('❌ Error fetching nearby clinics: $e');
      return [];
    }
  }
}

// Providers
final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  final supabaseClient = Supabase.instance.client;
  return ClinicRepository(client: supabaseClient);
});

// Provider for the new view
final allClinicsWithDoctorInfoProvider = FutureProvider<List<ClinicWithDoctorInfo>>((ref) {
  return ref.watch(clinicRepositoryProvider).getAllClinicsWithDoctorInfo();
});

// Original provider (can be removed if no longer used elsewhere)
final allClinicsProvider = FutureProvider<List<ClinicModel>>((ref) {
  return ref.watch(clinicRepositoryProvider).getAllClinics();
});

final userClinicProvider = FutureProvider.family<ClinicModel?, String>((ref, userId) {
  return ref.watch(clinicRepositoryProvider).getClinicByUserId(userId);
});
