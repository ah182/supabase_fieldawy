import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import

/// Performance Logger Service
/// Tracks performance metrics in Supabase (FREE!)
/// 
/// Usage:
/// ```dart
/// final result = await PerformanceLogger.trackQuery(
///   'get_users',
///   () => supabase.from('users').select(),
/// );
/// ```
class PerformanceLogger {
  static final _supabase = Supabase.instance.client;
  
  /// Track a Supabase query
  static Future<T> trackQuery<T>(
    String queryName,
    Future<T> Function() query, {
    String metricType = 'api_call',
    Map<String, dynamic>? extra,
  }) async {
    // Don't track in development
    if (kDebugMode) {
      return await query();
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await query();
      stopwatch.stop();
      
      // Log success
      _logMetric(
        metricType: metricType,
        metricName: queryName,
        durationMs: stopwatch.elapsedMilliseconds,
        success: true,
        extra: extra,
      );
      
      return result;
    } catch (e) {
      stopwatch.stop();
      
      // Log failure
      _logMetric(
        metricType: metricType,
        metricName: queryName,
        durationMs: stopwatch.elapsedMilliseconds,
        success: false,
        extra: {...?extra, 'error': e.toString()},
      );
      
      rethrow;
    }
  }

  /// Track screen load time
  static Future<void> trackScreenLoad(
    String screenName,
    int durationMs,
  ) async {
    if (kDebugMode) return;
    
    _logMetric(
      metricType: 'screen_load',
      metricName: screenName,
      durationMs: durationMs,
      success: true,
    );
  }

  /// Track custom metric
  static Future<void> trackCustom(
    String metricName,
    int durationMs, {
    bool success = true,
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) return;
    
    _logMetric(
      metricType: 'custom',
      metricName: metricName,
      durationMs: durationMs,
      success: success,
      extra: extra,
    );
  }

  /// Log metric to Supabase
  static void _logMetric({
    required String metricType,
    required String metricName,
    required int durationMs,
    required bool success,
    Map<String, dynamic>? extra,
  }) {
    try {
      // Get current user (optional)
      final userId = _supabase.auth.currentUser?.id;

      // Prepare metric data
      final metricData = {
        'metric_type': metricType,
        'metric_name': metricName,
        'duration_ms': durationMs,
        'success': success,
        'user_id': userId,
        'metadata': extra,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Log to Supabase (async, don't wait)
      NetworkGuard.execute(() async {
        await _supabase.from('performance_logs').insert(metricData);
      }).then(
        (_) {
          if (durationMs > 1000) {
            debugPrint('⚠️ Slow query: $metricName took ${durationMs}ms');
          }
        },
        onError: (e) => debugPrint('❌ Failed to log metric: $e'),
      );
    } catch (e) {
      // Don't crash if logging fails
      debugPrint('❌ Performance logger failed: $e');
    }
  }

  /// Wrapper class for timing operations
  static PerformanceTimer startTimer(String name) {
    return PerformanceTimer(name);
  }
}

/// Performance Timer helper class
class PerformanceTimer {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  
  PerformanceTimer(this.name) {
    _stopwatch.start();
  }
  
  /// Stop timer and log
  void stop({bool success = true, Map<String, dynamic>? extra}) {
    _stopwatch.stop();
    PerformanceLogger.trackCustom(
      name,
      _stopwatch.elapsedMilliseconds,
      success: success,
      extra: extra,
    );
  }
  
  /// Get elapsed time without stopping
  int get elapsedMs => _stopwatch.elapsedMilliseconds;
}
