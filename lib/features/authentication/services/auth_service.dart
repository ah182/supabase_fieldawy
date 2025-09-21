import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/user_repository.dart'; // افترض أن هذا الملف سيتم تعديله أيضاً

// AuthService الآن مسؤول فقط عن المصادقة باستخدام Supabase
class SupabaseAuthService {
  final GoTrueClient _auth;
  final UserRepository _userRepository;

  SupabaseAuthService({
    required GoTrueClient auth,
    required UserRepository userRepository,
  })  : _auth = auth,
        _userRepository = userRepository {
    // الاستماع لتغييرات حالة المصادقة لحفظ المستخدم الجديد تلقائياً
    // This is the best practice for OAuth providers
    _auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final user = data.session?.user;

      // عند تسجيل الدخول بنجاح لأول مرة (خصوصاً بعد العودة من OAuth)
      if (event == AuthChangeEvent.signedIn && user != null) {
        await _userRepository.saveNewUser(user);
      }
    });
  }

  // جلب المستخدم الحالي مباشرة
  User? get currentUser => _auth.currentUser;

  // Stream لتتبع تغييرات حالة المستخدم (تسجيل دخول/خروج)
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((data) => data.session?.user);

  // تسجيل الدخول باستخدام Google
  Future<void> signInWithGoogle() async {
    try {
      // Supabase v2 uses signInWithOAuth which handles everything.
      // It opens a web view or browser.
      // NOTE: You MUST configure URL schemes (deep linking) for this to work on mobile.
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.fieldawy://login-callback/', // For Mobile
      );
      // لا نحتاج لإرجاع المستخدم هنا، لأن onAuthStateChange سيتعامل مع الأمر
    } catch (e) {
      print('خطأ في تسجيل الدخول باستخدام Google مع Supabase: $e');
      // يمكنك التعامل مع الأخطاء هنا، مثلاً عرض رسالة للمستخدم
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      // A single call to signOut handles everything in Supabase
      await _auth.signOut();
    } catch (e) {
      print('خطأ في تسجيل الخروج من Supabase: $e');
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
