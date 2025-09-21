import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Web Client ID (serverClientId) — اللي أنت ذكرته
const kWebClientId =
    '665551059689-bb1albh5unnoh05erboo4s7piardjfsk.apps.googleusercontent.com';

// لو مش هتستخدم iOS سيبه فاضي أو احذفه
const String? kIosClientId = null;

class GoogleAuthService {
  final _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: kWebClientId, // مهم جداً ليرجع idToken على أندرويد
      // clientId: kIosClientId,     // فعّلها فقط لو بتبني iOS وبعندك iOS client id
      scopes: ['email', 'profile'],
    );

    final user = await googleSignIn.signIn();
    if (user == null) {
      throw Exception('Sign-in cancelled');
    }

    final auth = await user.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    if (idToken == null) {
      throw Exception('No idToken returned from GoogleSignIn');
    }

    // تبادل التوكن مع Supabase بدون متصفح
    final res = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return res;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await GoogleSignIn().signOut();
  }
}

// ✅ Provider للي حابب يحقنه عبر Riverpod
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});
