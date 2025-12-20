import 'dart:async';
import 'dart:io';
import 'package:retry/retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NetworkGuard {
  /// دالة ذكية تنفذ أي طلب مع ميزة إعادة المحاولة والتعامل مع الأخطاء
  static Future<T> execute<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final r = RetryOptions(maxAttempts: maxAttempts);

    try {
      return await r.retry(
        () async {
          // إضافة مهلة زمنية لكل محاولة
          return await action().timeout(timeout);
        },
        // المحاولة فقط في حالة أخطاء الشبكة
        retryIf: (e) => e is SocketException || 
                        e is TimeoutException || 
                        e is PostgrestException && e.code == 'PGRST',
      );
    } on TimeoutException {
      throw 'حدث بطء في الاتصال، يرجى المحاولة مرة أخرى';
    } on SocketException {
      throw 'تأكد من اتصالك بالإنترنت';
    } catch (e) {
      rethrow;
    }
  }
}
