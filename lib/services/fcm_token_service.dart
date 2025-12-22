import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import '../utils/string_extensions.dart';

class FCMTokenService {
  static final FCMTokenService _instance = FCMTokenService._internal();
  factory FCMTokenService() => _instance;
  FCMTokenService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// حفظ أو تحديث FCM Token في Supabase
  Future<void> saveToken(String token) async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        
        if (userId == null) {
          print('⚠️ لا يوجد مستخدم مسجل الدخول - لن يتم حفظ Token');
          return;
        }

        // الحصول على معلومات الجهاز
        String deviceType = 'Unknown';
        String? deviceName;
        
        try {
          final deviceInfo = DeviceInfoPlugin();
          
          // تحديد نوع المنصة أولاً
          if (kIsWeb) {
            // Web Platform
            deviceType = 'Web';
            try {
              final webInfo = await deviceInfo.webBrowserInfo;
              deviceName = '${webInfo.browserName} on ${webInfo.platform}';
              // مثال: Chrome on Windows
            } catch (e) {
              deviceName = 'Web Browser';
            }
          } else if (Platform.isAndroid) {
            // Android Platform
            deviceType = 'Android';
            try {
              final androidInfo = await deviceInfo.androidInfo;
              final manufacturer = androidInfo.manufacturer.capitalize();
              final model = androidInfo.model;
              deviceName = '$manufacturer $model';
              // مثال: Samsung SM-G991B
              print('📱 Android Info:');
              print('   Manufacturer: ${androidInfo.manufacturer}');
              print('   Model: ${androidInfo.model}');
              print('   Brand: ${androidInfo.brand}');
              print('   Device: ${androidInfo.device}');
              print('   Android Version: ${androidInfo.version.release}');
            } catch (e) {
              deviceName = 'Android Device';
              print('⚠️ خطأ في الحصول على معلومات Android: $e');
            }
          } else if (Platform.isIOS) {
            // iOS Platform
            deviceType = 'iOS';
            try {
              final iosInfo = await deviceInfo.iosInfo;
              deviceName = iosInfo.name;
              // مثال: iPhone 13
              print('📱 iOS Info:');
              print('   Name: ${iosInfo.name}');
              print('   Model: ${iosInfo.model}');
              print('   System Version: ${iosInfo.systemVersion}');
            } catch (e) {
              deviceName = 'iOS Device';
              print('⚠️ خطأ في الحصول على معلومات iOS: $e');
            }
          } else {
            // Other platforms (Linux, Windows, macOS)
            deviceType = 'Desktop';
            deviceName = Platform.operatingSystem;
          }
        } catch (e) {
          print('❌ خطأ عام في الحصول على معلومات الجهاز: $e');
          deviceType = 'Unknown';
          deviceName = 'Unknown Device';
        }

        // حفظ أو تحديث Token باستخدام الدالة المخصصة
        await _supabase.rpc('upsert_user_token', params: {
          'p_user_id': userId,
          'p_token': token,
          'p_device_type': deviceType,
          'p_device_name': deviceName,
        });

        print('✅ تم حفظ FCM Token في Supabase بنجاح');
        print('   User ID: $userId');
        print('   Device: $deviceType');
        print('   Device Name: $deviceName');
      } catch (e) {
        print('❌ خطأ في حفظ FCM Token: $e');
      }
    });
  }

  /// الحصول على FCM Token وحفظه
  Future<String?> getAndSaveToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      
      if (token != null) {
        print('🔑 تم الحصول على FCM Token: ${token.substring(0, 20)}...');
        await saveToken(token);
        return token;
      } else {
        print('❌ فشل الحصول على FCM Token');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في الحصول على FCM Token: $e');
      return null;
    }
  }

  /// حذف Token لمستخدم محدد عند تسجيل الخروج
  Future<void> deleteToken(String token) async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        
        if (userId == null) return;

        // حذف token للمستخدم الحالي فقط
        // لو نفس الجهاز مستخدم من حساب آخر، مش هيتأثر
        await _supabase.rpc('delete_user_token', params: {
          'p_user_id': userId,
          'p_token': token,
        });
        
        print('✅ تم حذف FCM Token من Supabase للمستخدم الحالي');
      } catch (e) {
        print('❌ خطأ في حذف FCM Token: $e');
      }
    });
  }

  /// حذف جميع tokens المستخدم الحالي
  Future<void> deleteAllUserTokens() async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        
        if (userId == null) return;

        await _supabase
            .from('user_tokens')
            .delete()
            .eq('user_id', userId);
        
        print('✅ تم حذف جميع FCM Tokens للمستخدم');
      } catch (e) {
        print('❌ خطأ في حذف FCM Tokens: $e');
      }
    });
  }

  /// الحصول على جميع tokens المستخدم الحالي
  Future<List<Map<String, dynamic>>> getUserTokens() async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        
        if (userId == null) return [];

        final response = await _supabase
            .rpc('get_user_tokens', params: {'p_user_id': userId});
        
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('❌ خطأ في الحصول على Tokens: $e');
        return [];
      }
    });
  }

  /// إعداد مستمع لتحديثات Token
  void setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 تم تحديث FCM Token');
      saveToken(newToken);
    });
  }

  /// إعداد كامل للـ FCM Token
  Future<void> initialize() async {
    // 1. الحصول على Token الحالي وحفظه
    await getAndSaveToken();
    
    // 2. إعداد مستمع للتحديثات
    setupTokenRefreshListener();
    
    print('✅ تم إعداد FCM Token Service');
  }
}
