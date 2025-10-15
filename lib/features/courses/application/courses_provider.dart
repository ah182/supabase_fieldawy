import 'package:fieldawy_store/features/courses/data/courses_repository.dart';
import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository Provider
final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository();
});

// All Courses Provider
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.read(coursesRepositoryProvider);
  return repository.getAllCourses();
});

// My Courses Provider
final myCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.read(coursesRepositoryProvider);
  return repository.getMyCourses();
});

// Courses State Notifier for mutations
class CoursesNotifier extends StateNotifier<AsyncValue<List<Course>>> {
  final CoursesRepository _repository;
  final bool _isMyCourses;

  CoursesNotifier(this._repository, {bool isMyCourses = false}) 
      : _isMyCourses = isMyCourses,
        super(const AsyncValue.loading()) {
    loadCourses();
  }

  Future<void> loadCourses() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (_isMyCourses) {
        return _repository.getMyCourses();
      } else {
        return _repository.getAllCourses();
      }
    });
  }

  Future<bool> createCourse({
    required String title,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      await _repository.createCourse(
        title: title,
        description: description,
        price: price,
        phone: phone,
        imageUrl: imageUrl,
      );
      await loadCourses();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCourse({
    required String courseId,
    required String title,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final success = await _repository.updateCourse(
        courseId: courseId,
        title: title,
        description: description,
        price: price,
        phone: phone,
        imageUrl: imageUrl,
      );
      if (success) {
        await loadCourses();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCourse(String courseId) async {
    try {
      final success = await _repository.deleteCourse(courseId);
      if (success) {
        await loadCourses();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> incrementViews(String courseId) async {
    await _repository.incrementCourseViews(courseId);
  }
}

// All Courses Notifier Provider
final allCoursesNotifierProvider = StateNotifierProvider<CoursesNotifier, AsyncValue<List<Course>>>((ref) {
  final repository = ref.read(coursesRepositoryProvider);
  return CoursesNotifier(repository, isMyCourses: false);
});

// My Courses Notifier Provider
final myCoursesNotifierProvider = StateNotifierProvider<CoursesNotifier, AsyncValue<List<Course>>>((ref) {
  final repository = ref.read(coursesRepositoryProvider);
  return CoursesNotifier(repository, isMyCourses: true);
});

// ===================================================================
// ADMIN PROVIDERS
// ===================================================================

// Admin: All Courses Provider
final adminAllCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.read(coursesRepositoryProvider);
  return repository.adminGetAllCourses();
});
