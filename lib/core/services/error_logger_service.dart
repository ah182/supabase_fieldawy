import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import

/// Error Logger Service
/// Logs errors to Supabase (FREE!)
/// 
/// Usage:
/// ```dart
/// try {
///   // Your code
/// } catch (e, stack) {
///   ErrorLogger.log(e, stack);
/// }
/// ```
class ErrorLogger {
  static final _supabase = Supabase.instance.client;
  
  /// Log an error to Supabase
  static Future<void> log(
    Object error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  ]) async {
    try {
      // Don't log in development (save bandwidth)
      if (kDebugMode) {
        debugPrint('🐛 ERROR: $error');
        if (stackTrace != null) debugPrint('Stack: $stackTrace');
        return;
      }

      // Get current user (if available)
      final userId = _supabase.auth.currentUser?.id;
      final userEmail = _supabase.auth.currentUser?.email;

      // Prepare error data
      final errorData = {
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'user_id': userId,
        'user_email': userEmail,
        'platform': _getPlatform(),
        'metadata': extra,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Log to Supabase (async, don't wait)
      NetworkGuard.execute(() async {
        await _supabase.from('error_logs').insert(errorData);
      }).then(
        (_) => debugPrint('✅ Error logged to Supabase'),
        onError: (e) => debugPrint('❌ Failed to log error: $e'),
      );
    } catch (e) {
      // Don't crash if logging fails
      debugPrint('❌ Error logger failed: $e');
    }
  }

  /// Log error with route context
  static Future<void> logWithRoute(
    Object error,
    String route, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  ]) async {
    final metadata = {
      ...?extra,
      'route': route,
    };
    await log(error, stackTrace, metadata);
  }

  /// Get platform name
  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }
}
