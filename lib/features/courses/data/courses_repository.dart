import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoursesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all courses
  Future<List<Course>> getAllCourses() async {
    try {
      final response = await _supabase.rpc('get_all_courses');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Course.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }

  /// Get current user's courses
  Future<List<Course>> getMyCourses() async {
    try {
      final response = await _supabase.rpc('get_my_courses');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Course.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load my courses: $e');
    }
  }

  /// Create a new course
  Future<String> createCourse({
    required String title,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('create_course', params: {
        'p_title': title,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      return response as String;
    } catch (e) {
      throw Exception('Failed to create course: $e');
    }
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
    try {
      final response = await _supabase.rpc('update_course', params: {
        'p_course_id': courseId,
        'p_title': title,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to update course: $e');
    }
  }

  /// Delete a course
  Future<bool> deleteCourse(String courseId) async {
    try {
      final response = await _supabase.rpc('delete_course', params: {
        'p_course_id': courseId,
      });
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  /// Increment course views
  Future<void> incrementCourseViews(String courseId) async {
    try {
      await _supabase.rpc('increment_course_views', params: {
        'p_course_id': courseId,
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
  }

  /// Admin: Delete any course
  Future<bool> adminDeleteCourse(String courseId) async {
    try {
      await _supabase.from('vet_courses').delete().eq('id', courseId);
      return true;
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  /// Admin: Update any course
  Future<bool> adminUpdateCourse({
    required String courseId,
    required String title,
    required double price,
    required String phone,
    required String description,
  }) async {
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
      
      return true;
    } catch (e) {
      throw Exception('Failed to update course: $e');
    }
  }
}
