import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Activity Log Model
class ActivityLog {
  final String id;
  final String activityType;
  final String? userId;
  final String? userName;
  final String? userRole;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.activityType,
    this.userId,
    this.userName,
    this.userRole,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      activityType: json['activity_type'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      userRole: json['user_role'] as String?,
      description: json['description'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activity_type': activityType,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Activity Repository
class ActivityRepository {
  final SupabaseClient _supabase;

  ActivityRepository({required SupabaseClient supabase}) : _supabase = supabase;

  // Get recent activities (last N activities)
  Future<List<ActivityLog>> getRecentActivities({int limit = 20}) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ActivityLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent activities: $e');
    }
  }

  // Get activities by type
  Future<List<ActivityLog>> getActivitiesByType(String activityType, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('activity_type', activityType)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ActivityLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch activities by type: $e');
    }
  }

  // Get activities by user
  Future<List<ActivityLog>> getActivitiesByUser(String userId, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ActivityLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch activities by user: $e');
    }
  }

  // Log a custom activity (manual logging)
  Future<ActivityLog> logActivity({
    required String activityType,
    String? userId,
    String? userName,
    String? userRole,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .insert({
            'activity_type': activityType,
            'user_id': userId,
            'user_name': userName,
            'user_role': userRole,
            'description': description,
            'metadata': metadata,
          })
          .select()
          .single();

      return ActivityLog.fromJson(response);
    } catch (e) {
      throw Exception('Failed to log activity: $e');
    }
  }

  // Get activities count by type
  Future<Map<String, int>> getActivitiesCountByType() async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select('activity_type')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      final Map<String, int> counts = {};
      for (var item in data) {
        final type = item['activity_type'] as String;
        counts[type] = (counts[type] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      throw Exception('Failed to get activities count: $e');
    }
  }

  // Delete old activities (older than days)
  Future<int> deleteOldActivities({int olderThanDays = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      
      final response = await _supabase
          .from('activity_logs')
          .delete()
          .lt('created_at', cutoffDate.toIso8601String())
          .select();

      final List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      throw Exception('Failed to delete old activities: $e');
    }
  }
}

// Providers
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(supabase: Supabase.instance.client);
});

final recentActivitiesProvider = FutureProvider<List<ActivityLog>>((ref) {
  return ref.watch(activityRepositoryProvider).getRecentActivities(limit: 20);
});

final activitiesCountByTypeProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(activityRepositoryProvider).getActivitiesCountByType();
});

// Stream provider for real-time updates (optional)
final activityStreamProvider = StreamProvider<List<ActivityLog>>((ref) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('activity_logs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(20)
      .map((data) {
        return data.map((json) => ActivityLog.fromJson(json)).toList();
      });
});
