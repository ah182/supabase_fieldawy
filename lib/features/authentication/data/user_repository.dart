import 'package:fieldawy_store/core/caching/caching_service.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_model.dart'; // تأكد أن هذا الملف معدل أيضاً

class UserRepository {
  final SupabaseClient _client;
  final CachingService _cache;

  // استلام SupabaseClient و CachingService عبر الـ constructor
  UserRepository({required SupabaseClient client, required CachingService cache})
      : _client = client,
        _cache = cache;

  // دالة لحفظ مستخدم جديد أو تحديث بياناته إذا كان موجوداً
  // تستخدم 'upsert' لتجنب الأخطاء وللكفاءة
  Future<void> saveNewUser(User user) async {
    try {
      final userMap = {
        'id': user.id,
        'display_name': user.userMetadata?['full_name'] ?? user.email,
        'email': user.email,
        'photo_url': user.userMetadata?['avatar_url'],
        'role': 'viewer',
        'account_status': 'pending_review',
        'is_profile_complete': false,
      };

      // Attempt to insert the user.
      await _client.from('users').insert(userMap);
      // Invalidate distributors cache if a new distributor/company is added
      if (userMap['role'] == 'distributor' || userMap['role'] == 'company') {
        _cache.invalidate('distributors');
      }
    } on PostgrestException catch (e) {
      // If it's a duplicate key error (code 23505), it means the user already exists.
      // In this case, we can safely ignore the error as the user data is already present.
      if (e.code == '23505') {
        print('User with ID ${user.id} already exists in DB. Skipping insert.');
      } else {
        // Re-throw other PostgrestExceptions
        print('Error saving new user to Supabase: $e');
        rethrow;
      }
    } catch (e) {
      // Catch any other unexpected errors
      print('Error saving new user to Supabase: $e');
      rethrow;
    }
  }

  // دالة لإكمال ملف المستخدم بعد التسجيل
  Future<void> completeUserProfile({
    required String id,
    required String role,
    required String documentUrl,
    required String displayName,
    required String whatsappNumber,
  }) async {
    try {
      await _client.from('users').update({
        'role': role,
        'document_url': documentUrl,
        'display_name': displayName,
        'whatsapp_number': whatsappNumber,
        'is_profile_complete': true, // الأهم: تغيير حالة اكتمال الملف
      }).eq('id', id); // شرط التحديث: حيث id = القيمة المعطاة
      _cache.invalidate('distributors');
    } catch (e) {
      print('Error completing user profile in Supabase: $e');
      rethrow;
    }
  }

  // دالة لجلب بيانات المستخدم مرة واحدة
  Future<UserModel?> getUser(String id) async {
    final cacheKey = 'user_$id';
    final cachedUser = _cache.get<UserModel>(cacheKey);

    if (cachedUser != null) {
      return cachedUser;
    }

    try {
      // التأكد من أن الـ id ليس فارغاً لتجنب الأخطاء
      if (id.isEmpty) return null;

      final data = await _client.from('users').select().eq('id', id).single();

      final user = UserModel.fromMap(data);
      _cache.set(cacheKey, user);
      return user;
    } catch (e) {
      print('Error fetching user data once: $e');
      // إرجاع null في حالة حدوث خطأ أو عدم العثور على المستخدم
      return null;
    }
  }

  // دالة لإعادة بدء عملية التسجيل للمستخدم المرفوض
  Future<void> reInitiateOnboarding(String id) async {
    try {
      await _client.from('users').update({
        'account_status': 'pending_re_review',
        'is_profile_complete': false,
      }).eq('id', id);
      _cache.invalidate('distributors');
    } catch (e) {
      print('Error re-initiating onboarding in Supabase: $e');
      rethrow;
    }
  }
} // Added this closing brace for UserRepository class

// Provider المحدث ليعمل مع Supabase
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final supabaseClient = Supabase.instance.client;
  final cachingService = ref.watch(cachingServiceProvider);
  return UserRepository(client: supabaseClient, cache: cachingService);
});
