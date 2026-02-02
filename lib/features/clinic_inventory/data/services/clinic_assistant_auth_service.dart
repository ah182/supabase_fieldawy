import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider to store the authenticated Assistant's Target Doctor ID
/// If this is not null, the app is in "Assistant Mode"
final clinicAssistantUserIdProvider = StateProvider<String?>((ref) => null);

/// Service to handle Clinic Assistant Authentication
class ClinicAssistantAuthService {
  final SupabaseClient _supabase;
  final Ref _ref;

  ClinicAssistantAuthService(this._supabase, this._ref);

  /// Verify the access code and log in as assistant
  /// Returns true if successful
  Future<bool> verifyAndLogin(String accessCode) async {
    try {
      final code = accessCode.trim().toUpperCase(); // Normalize format
      if (code.isEmpty) return false;

      // Call the RPC function to find the user ID associated with this code
      final response =
          await _supabase.rpc('get_user_id_by_clinic_code', params: {
        'code_input': code,
      });

      if (response != null) {
        final userId = response as String;
        // set the global state
        _ref.read(clinicAssistantUserIdProvider.notifier).state = userId;
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error verifying clinic access code: $e');
      return false;
    }
  }

  /// Logout assistant (clear the state)
  void logout() {
    _ref.read(clinicAssistantUserIdProvider.notifier).state = null;
  }
}

final clinicAssistantAuthServiceProvider =
    Provider<ClinicAssistantAuthService>((ref) {
  return ClinicAssistantAuthService(Supabase.instance.client, ref);
});
