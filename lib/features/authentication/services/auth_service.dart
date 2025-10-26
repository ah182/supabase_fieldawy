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
          serverClientId: '665551059689-bb1albh5unnoh05erboo4s7piardjfsk.apps.googleusercontent.com',
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
        );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((data) => data.session?.user);

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google Sign-In failed: Missing ID token.';
      }

      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        throw 'Sign-in failed: No user returned from Supabase';
      }

      final isNewUser = await _userRepository.saveNewUser(user);
      return isNewUser;

    } catch (e) {
      print('Error signing in with Google: $e');
      await _googleSignIn.signOut();
      rethrow;
    }
  }

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
