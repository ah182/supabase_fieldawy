import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupaKeys {
  // Hardcoded values for Web (since .env doesn't work in Flutter Web)
  // Note: For better security on web, consider loading these from a config.json at runtime
  static const String _webSupabaseUrl = 'https://rkukzuwerbvmueuxadul.supabase.co';
  static const String _webSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4NTcwODcsImV4cCI6MjA3MzQzMzA4N30.Rs69KRvvB8u6A91ZXIzkmWebO_IyavZXJrO-SXa2_mc';
  
  static String get url {
    if (kIsWeb) {
      // For Web: use hardcoded values
      return _webSupabaseUrl;
    }
    // For Mobile/Desktop: get from .env
    return dotenv.env['SUPABASE_URL'] ?? '';
  }
  
  static String get anon {
    if (kIsWeb) {
      // For Web: use hardcoded values
      return _webSupabaseAnonKey;
    }
    // For Mobile/Desktop: get from .env
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}

Future<void> initSupabase() async {
  if (SupaKeys.url.isEmpty || SupaKeys.anon.isEmpty) {
    throw Exception(
      'Supabase keys are missing. Check your .env file (SUPABASE_URL and SUPABASE_ANON_KEY).',
    );
  }

  await Supabase.initialize(
    url: SupaKeys.url,
    anonKey: SupaKeys.anon,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      // لسه موجود
      // detectSessionInUrl اتشالت في v2
    ),
    debug: true,
  );
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
