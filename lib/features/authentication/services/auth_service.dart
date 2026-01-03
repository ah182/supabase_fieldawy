import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import

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
          serverClientId: '665551059689-h6md8lhpskrquaje7ffhlth0vpqd1ph0.apps.googleusercontent.com',
          scopes: [
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
          ],
        );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((data) => data.session?.user);

  Future<bool> signInWithGoogle() async {
    return await NetworkGuard.execute(() async {
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

        // Defer saving to public database until profile completion
        // final isNewUser = await _userRepository.saveNewUser(user);
        return true;

      } catch (e) {
        print('Error signing in with Google: $e');
        await _googleSignIn.signOut();
        rethrow;
      }
    });
  }

  Future<bool> signInAnonymously() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _auth.signInAnonymously();
        final user = response.user;
        
        if (user == null) {
          throw 'Sign-in failed: No user returned from Supabase';
        }

        // Defer saving to public database until profile completion
        // final isNewUser = await _userRepository.saveNewUser(user);
        return true;
      } catch (e) {
        print('Error signing in anonymously: $e');
        rethrow;
      }
    });
  }

  Future<void> linkIdentity({required String email, required String password}) async {
    return await NetworkGuard.execute(() async {
      try {
        final UserResponse res = await _auth.updateUser(
          UserAttributes(
            email: email,
            password: password,
          ),
        );
        
        if (res.user != null) {
          // Sync with public.users table
          await _userRepository.linkUserIdentity(
            id: res.user!.id,
            email: email,
            password: password,
          );
        }
      } catch (e) {
        print('Error linking identity: $e');
        rethrow;
      }
    });
  }

  Future<AuthResponse> signInWithEmailAndPassword({required String email, required String password}) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _auth.signInWithPassword(
          email: email,
          password: password,
        );
        return response;
      } catch (e) {
        print('Error signing in with email/password: $e');
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    await NetworkGuard.execute(() async {
      try {
        // Sign out from Supabase and Google to allow account selection next time.
        await Future.wait([
          _auth.signOut(),
          _googleSignIn.signOut(),
        ]);
      } catch (e) {
        print('Error signing out: $e');
      }
    });
  }

  Future<void> deleteAccount() async {
    await NetworkGuard.execute(() async {
      try {
        final userId = currentUser?.id;
        if (userId == null) throw 'No user logged in';

        // Call Supabase RPC to delete user data (and trigger auth deletion via Edge Function or Postgres Trigger if set up)
        // For strict Google Play compliance, we often need a dedicated Edge Function or a 'soft delete' flag first.
        // Here we assume an RPC 'delete_own_account' exists which deletes public.users entry.
        // The actual auth.users deletion usually requires Service Role key in an Edge Function.
        
        // For now, we'll try to call an RPC that handles data cleanup.
        await Supabase.instance.client.rpc('delete_own_account');

        await signOut();
      } catch (e) {
        print('Error deleting account: $e');
        // If RPC fails (e.g. doesn't exist yet), just sign out for UI demo purposes
        // In production, you MUST ensure the account is actually deleted or flagged.
        await signOut();
        rethrow; 
      }
    });
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