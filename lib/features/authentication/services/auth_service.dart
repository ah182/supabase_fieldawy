import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import '../data/user_repository.dart';

// AuthService uses native Google Sign-In and Supabase
class SupabaseAuthService {
  final GoTrueClient _auth;
  final UserRepository _userRepository;
  final GoogleSignIn _googleSignIn;

  SupabaseAuthService({
    required GoTrueClient auth,
    required UserRepository userRepository,
  })  : _auth = auth,
        _userRepository = userRepository,
        _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
        ) {
    // Listen to auth state changes to save new user automatically
    _auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final user = data.session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        await _userRepository.saveNewUser(user);
      }
    });
  }

  // Current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((data) => data.session?.user);

  // Sign in with Google using native flow
  Future<void> signInWithGoogle() async {
    try {
      // 1. Trigger the native Google authentication flow.
      final googleUser = await _googleSignIn.signIn();

      // 2. Obtain the auth details from the request.
      if (googleUser == null) {
        // The user canceled the sign-in.
        return;
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google Sign-In failed: Missing ID token.';
      }

      // 3. Sign in to Supabase with the ID token.
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      print('Error signing in with Google: $e');
      // Optionally, sign out from Google to allow retry
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Supabase and Google to allow account selection next time.
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}

// --- Providers المحدثة ---

// Provider لخدمة المصادغة الجديدة
final authServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(
    auth: Supabase.instance.client.auth, // الحصول على عميل المصادقة من Supabase
    userRepository:
        ref.watch(userRepositoryProvider), // لا يزال يعتمد على UserRepository
  );
});

// StreamProvider لمراقبة تغييرات حالة المصادقة
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
