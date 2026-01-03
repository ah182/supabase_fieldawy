import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SupaKeys {
  // Use dotenv to get keys
  static String get url {
    return dotenv.env['SUPABASE_URL'] ?? 'https://rkukzuwerbvmueuxadul.supabase.co';
  }
  
  static String get anon {
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
