import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/services/fcm_token_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider للـ FCMTokenService
final fcmTokenServiceProvider = Provider<FCMTokenService>((ref) {
  return FCMTokenService();
});

/// Provider لمراقبة حالة المستخدم وحفظ Token تلقائياً
final fcmTokenInitializerProvider = Provider<FCMTokenInitializer>((ref) {
  return FCMTokenInitializer(ref);
});

class FCMTokenInitializer {
  final Ref ref;
  
  FCMTokenInitializer(this.ref) {
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // الاستماع لتغييرات حالة المصادقة
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // عند تسجيل الدخول، احفظ Token
        print('🔐 تم تسجيل الدخول - جاري حفظ FCM Token...');
        _saveToken();
      } else if (event == AuthChangeEvent.signedOut) {
        // عند تسجيل الخروج، احذف Token (اختياري)
        print('🚪 تم تسجيل الخروج');
        // يمكنك حذف Token إذا أردت
        // ref.read(fcmTokenServiceProvider).deleteAllUserTokens();
      }
    });
  }

  Future<void> _saveToken() async {
    try {
      final fcmService = ref.read(fcmTokenServiceProvider);
      await fcmService.getAndSaveToken();
    } catch (e) {
      print('❌ خطأ في حفظ FCM Token بعد تسجيل الدخول: $e');
    }
  }

  /// استدعاء هذه الدالة يدوياً إذا احتجت
  Future<void> initialize() async {
    final fcmService = ref.read(fcmTokenServiceProvider);
    await fcmService.initialize();
  }
}
