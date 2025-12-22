import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoursesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  CoursesRepository(this._cache);

  /// Get all courses
  Future<List<Course>> getAllCourses() async {
    // استخدام Cache-First للكورسات (تتغير ببطء)
    return await _cache.cacheFirst<List<Course>>(
      key: 'all_courses',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllCourses,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => Course.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<Course>> _fetchAllCourses() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_all_courses');
        
        if (response == null) return [];
        
        final List<dynamic> data = response as List<dynamic>;
        // Cache as JSON List instead of Course objects
        _cache.set('all_courses', data, duration: CacheDurations.long);
        return data.map((json) => Course.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        throw Exception('Failed to load courses: $e');
      }
    });
  }

  /// Get current user's courses
  Future<List<Course>> getMyCourses() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Stale-While-Revalidate لكورسات المستخدم
    return await _cache.staleWhileRevalidate<List<Course>>(
      key: 'my_courses_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: _fetchMyCourses,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => Course.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<Course>> _fetchMyCourses() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_my_courses');
        
        if (response == null) return [];
        
        final List<dynamic> data = response as List<dynamic>;
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          _cache.set('my_courses_$userId', data, duration: CacheDurations.medium);
        }
        return data.map((json) => Course.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        throw Exception('Failed to load my courses: $e');
      }
    });
  }

  /// Create a new course
  Future<String> createCourse({
    required String title,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('create_course', params: {
          'p_title': title,
          'p_description': description,
          'p_price': price,
          'p_phone': phone,
          'p_image_url': imageUrl,
        });
        
        // حذف الكاش بعد الإضافة
        _invalidateCoursesCache();
        
        return response as String;
      } catch (e) {
        throw Exception('Failed to create course: $e');
      }
    });
  }

  /// Update an existing course
  Future<bool> updateCourse({
    required String courseId,
    required String title,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('update_course', params: {
          'p_course_id': courseId,
          'p_title': title,
          'p_description': description,
          'p_price': price,
          'p_phone': phone,
          'p_image_url': imageUrl,
        });
        
        // حذف الكاش بعد التعديل
        _invalidateCoursesCache();
        
        return response as bool;
      } catch (e) {
        throw Exception('Failed to update course: $e');
      }
    });
  }

  /// Delete a course
  Future<bool> deleteCourse(String courseId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('delete_course', params: {
          'p_course_id': courseId,
        });
        
        // حذف الكاش بعد الحذف
        _invalidateCoursesCache();
        
        return response as bool;
      } catch (e) {
        throw Exception('Failed to delete course: $e');
      }
    });
  }

  /// حذف كاش الكورسات
  void _invalidateCoursesCache() {
    _cache.invalidate('all_courses');
    _cache.invalidateWithPrefix('my_courses_');
    print('🧹 Courses cache invalidated');
  }

  /// Increment course views
  Future<void> incrementCourseViews(String courseId) async {
    try {
      await NetworkGuard.execute(() async {
        await _supabase.rpc('increment_course_views', params: {
          'p_course_id': courseId,
        });
      });
    } catch (e) {
      // Silent fail for views
      print('Failed to increment course views: $e');
    }
  }
  
  // ===================================================================
  // ADMIN METHODS
  // ===================================================================
  
  /// Admin: Get all courses
  Future<List<Course>> adminGetAllCourses() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase
            .from('vet_courses')
            .select()
            .order('created_at', ascending: false);
        
        return (response as List<dynamic>)
            .map((json) => Course.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw Exception('Failed to load all courses: $e');
      }
    });
  }

  /// Admin: Delete any course
  Future<bool> adminDeleteCourse(String courseId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.from('vet_courses').delete().eq('id', courseId);
        
        // حذف الكاش
        _invalidateCoursesCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to delete course: $e');
      }
    });
  }

  /// Admin: Update any course
  Future<bool> adminUpdateCourse({
    required String courseId,
    required String title,
    required double price,
    required String phone,
    required String description,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase
            .from('vet_courses')
            .update({
              'title': title,
              'price': price,
              'phone': phone,
              'description': description,
            })
            .eq('id', courseId);
        
        // حذف الكاش
        _invalidateCoursesCache();
        
        return true;
      } catch (e) {
        throw Exception('Failed to update course: $e');
      }
    });
  }
}

// Provider
final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return CoursesRepository(cache);
});
