// ignore_for_file: unnecessary_type_check

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
  Future<bool> saveNewUser(User user) async {
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
      return true; // User was inserted
    } on PostgrestException catch (e) {
      // If it's a duplicate key error (code 23505), it means the user already exists.
      if (e.code == '23505') {
        print('User with ID ${user.id} already exists in DB. Skipping insert.');
        return false; // User already existed
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
    required List<String> governorates,
    required List<String> centers,
    String? distributionMethod,
  }) async {
    try {
      final updateData = {
        'role': role,
        'document_url': documentUrl,
        'display_name': displayName,
        'whatsapp_number': whatsappNumber,
        'governorates': governorates,
        'centers': centers,
        'is_profile_complete': true, // الأهم: تغيير حالة اكتمال الملف
      };

      if (distributionMethod != null) {
        updateData['distribution_method'] = distributionMethod;
      }

      await _client.from('users').update(updateData).eq('id', id); // شرط التحديث: حيث id = القيمة المعطاة
      _cache.invalidate('distributors'); // This is for distributors, not user.

      // Invalidate the user cache after updating the profile
      _cache.invalidate('user_$id'); // Add this line

    } catch (e) {
      print('Error completing user profile in Supabase: $e');
      rethrow;
    }
    
  }

  Future<void> updateUserProfile({
    required String id,
    required String displayName,
    required String whatsappNumber,
    required List<String> governorates,
    required List<String> centers,
    String? role,
    String? distributionMethod,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'display_name': displayName,
        'whatsapp_number': whatsappNumber,
        'governorates': governorates,
        'centers': centers,
      };
      
      if (role != null) {
        updateData['role'] = role;
      }
      
      if (distributionMethod != null) {
        updateData['distribution_method'] = distributionMethod;
      }

      await _client.from('users').update(updateData).eq('id', id);
      _cache.invalidate('user_$id');
    } catch (e) {
      print('Error updating user profile in Supabase: $e');
      rethrow;
    }
  }

  // Update user profile image
  Future<void> updateProfileImage(String userId, String photoUrl) async {
    try {
      await _client.from('users').update({
        'photo_url': photoUrl,
      }).eq('id', userId);
      
      _cache.invalidate('user_$userId');
    } catch (e) {
      print('Error updating profile image in Supabase: $e');
      rethrow;
    }
  }

  // دالة لجلب بيانات المستخدم مرة واحدة
  Future<UserModel?> getUser(String id) async {
    final cacheKey = 'user_$id';
    final cachedUser = _cache.get<UserModel>(cacheKey);

    if (cachedUser != null && cachedUser.referralCode != null) {
      return cachedUser;
    }

    try {
      if (id.isEmpty) return null;

      final data = await _client.from('users').select().eq('id', id).maybeSingle();

      if (data == null) {
        return null;
      }

      var user = UserModel.fromMap(data);

      // If referral code is missing (for old users), generate one now.
      if (user.referralCode == null || user.referralCode!.isEmpty) {
        final newCode = await _client.rpc('generate_and_get_code', params: {'user_id_param': user.id}) as String?;
        if (newCode != null) {
          user = user.copyWith(referralCode: newCode);
        }
      }

      _cache.set(cacheKey, user);
      return user;
    } catch (e) {
      print('Error fetching user data once: $e');
      if (cachedUser != null) {
        return cachedUser;
      }
      rethrow;
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
  Future<int> getTotalUsersCount() async {
    try {
      final count = await _client.from('users').count(CountOption.exact);
      return count;
    } catch (e) {
      print('Error counting users: $e');
      return 0;
    }
  }

  // ===================================================================
  // Admin Functions for User Management
  // ===================================================================

  // Get count by role
  Future<int> getUsersCountByRole(String role) async {
    try {
      final count = await _client
          .from('users')
          .count(CountOption.exact)
          .eq('role', role);
      return count;
    } catch (e) {
      print('Error counting users by role: $e');
      return 0;
    }
  }

  // Get all users with specific role
  Future<List<UserModel>> getUsersByRole(String role) async {
    // استخدام Cache-First للمستخدمين حسب الدور
    return await _cache.cacheFirst<List<UserModel>>(
      key: 'users_by_role_$role',
      duration: CacheDurations.medium, // 30 دقيقة
      fetchFromNetwork: () => _fetchUsersByRole(role),
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => UserModel.fromMap(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<UserModel>> _fetchUsersByRole(String role) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('role', role)
          .order('created_at', ascending: false);
      
      final List<dynamic> data = response as List;
      
      // Cache as JSON List
      _cache.set('users_by_role_$role', data, duration: CacheDurations.medium);
      
      return data.map((json) => UserModel.fromMap(json)).toList();
    } catch (e) {
      print('Error fetching users by role: $e');
      return [];
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    // استخدام Cache-First للمستخدمين (تتغير ببطء)
    return await _cache.cacheFirst<List<UserModel>>(
      key: 'all_users',
      duration: CacheDurations.medium, // 30 دقيقة
      fetchFromNetwork: _fetchAllUsers,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => UserModel.fromMap(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<UserModel>> _fetchAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      
      final List<dynamic> data = response as List;
      
      // Cache as JSON List
      _cache.set('all_users', data, duration: CacheDurations.medium);
      
      return data.map((json) => UserModel.fromMap(json)).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  // Delete user (admin only)
  Future<bool> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
      
      // حذف الكاش بعد الحذف
      _invalidateUsersCache(userId);
      
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Update user role (admin only)
  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      await _client.from('users').update({
        'role': newRole,
      }).eq('id', userId);
      
      // حذف الكاش بعد التحديث
      _invalidateUsersCache(userId);
      
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  // Update user location
  Future<bool> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      print('📍 Updating location for user $userId: ($latitude, $longitude)');
      
      // Call the Supabase function
      await _client.rpc('update_user_location', params: {
        'p_user_id': userId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
      
      // Invalidate cache
      _cache.invalidate('user_$userId');
      
      print('✅ Location updated successfully');
      return true;
    } on PostgrestException catch (e) {
      if (e.message.contains('wait 30 seconds')) {
        print('⏰ Rate limit: Please wait before updating again');
      } else {
        print('❌ Error updating user location: ${e.message}');
      }
      return false;
    } catch (e) {
      print('❌ Error updating user location: $e');
      return false;
    }
  }

  // Update user status (admin only)
  Future<bool> updateUserStatus(String userId, String newStatus) async {
    try {
      print('📝 Attempting to update user $userId to status: $newStatus');
      print('🔑 Current auth user: ${_client.auth.currentUser?.id}');
      
      // Try without RLS first (direct update)
      final response = await _client
          .from('users')
          .update({
            'account_status': newStatus,
          })
          .eq('id', userId)
          .select();
      
      print('📦 Response from Supabase: $response');
      print('📊 Response type: ${response.runtimeType}');
     
      
      // Invalidate all relevant caches
      _cache.invalidate('user_$userId');
      _cache.invalidate('distributors');
      _cache.invalidate('doctors');
      _cache.invalidate('all_users');
      
      final success = response is List && response.isNotEmpty;
      print(success ? '✅ Status updated successfully' : '❌ Update failed - empty response');
      
      if (!success) {
        print('🔍 Debug: Checking if RLS is blocking the update...');
        // Try to fetch the user to see if we can read
        final readTest = await _client.from('users').select().eq('id', userId).single();
        // ignore: unnecessary_null_comparison
        print('🔍 Can read user: ${readTest != null}');
      }
      
      return success;
    } catch (e, stackTrace) {
      print('❌❌ Error updating user status: $e');
      print('📚 Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Check if a user has been invited
  Future<bool> wasInvited(String userId) async {
    try {
      final response = await _client
          .from('referrals')
          .select('id')
          .eq('invited_id', userId)
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      print('Error checking if user was invited: $e');
      // In case of error, assume they were invited to avoid showing the screen repeatedly.
      return true;
    }
  }

  /// زيادة عدد المشتركين لمستخدم معين
  Future<void> incrementSubscribers(String userId) async {
    try {
      await _client.rpc('increment_subscribers', params: {'user_id': userId});
      // لا نقوم بحذف الكاش هنا لتجنب تحميل القائمة بالكامل، 
      // التحديث المحلي في الواجهة كافٍ للسرعة
    } catch (e) {
      print('Error incrementing subscribers: $e');
      // في حال فشل الـ RPC (لم يتم إنشاؤه بعد)، نحاول التحديث اليدوي كبديل مؤقت
      await _manualUpdateSubscribers(userId, 1);
    }
  }

  /// إنقاص عدد المشتركين لمستخدم معين
  Future<void> decrementSubscribers(String userId) async {
    try {
      await _client.rpc('decrement_subscribers', params: {'user_id': userId});
    } catch (e) {
      print('Error decrementing subscribers: $e');
       await _manualUpdateSubscribers(userId, -1);
    }
  }

  // دالة بديلة يدوية (غير ذرية) في حال عدم وجود RPC
  Future<void> _manualUpdateSubscribers(String userId, int change) async {
    try {
      final user = await _client.from('users').select('subscribers_count').eq('id', userId).single();
      final currentCount = (user['subscribers_count'] as int?) ?? 0;
      final newCount = (currentCount + change) < 0 ? 0 : (currentCount + change);
      
      await _client.from('users').update({'subscribers_count': newCount}).eq('id', userId);
    } catch (e) {
      print('Error manually updating subscribers: $e');
    }
  }

  /// حذف كاش المستخدمين
  void _invalidateUsersCache(String? userId) {
    // حذف كاش المستخدم المحدد
    if (userId != null) {
      _cache.invalidate('user_$userId');
    }
    
    // حذف كاش القوائم
    _cache.invalidate('all_users');
    _cache.invalidateWithPrefix('users_by_role_');
    _cache.invalidate('distributors');
    _cache.invalidate('doctors');
    
    print('🧹 Users cache invalidated');
  }
} // Added this closing brace for UserRepository class

// Provider المحدث ليعمل مع Supabase
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final supabaseClient = Supabase.instance.client;
  final cachingService = ref.watch(cachingServiceProvider);
  return UserRepository(client: supabaseClient, cache: cachingService);
});

final totalUsersProvider = FutureProvider<int>((ref) {
  return ref.watch(userRepositoryProvider).getTotalUsersCount();
});

// Admin Providers
final doctorsCountProvider = FutureProvider<int>((ref) {
  return ref.watch(userRepositoryProvider).getUsersCountByRole('doctor');
});

final distributorsCountProvider = FutureProvider<int>((ref) {
  return ref.watch(userRepositoryProvider).getUsersCountByRole('distributor');
});
final companiesCountProvider = FutureProvider<int>((ref) {
  return ref.watch(userRepositoryProvider).getUsersCountByRole('company');
});

final allDoctorsProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).getUsersByRole('doctor');
});

final allDistributorsProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).getUsersByRole('distributor');
});

final allUsersListProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).getAllUsers();
});

final wasInvitedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final userId = authState.asData?.value?.id;

  if (userId == null) {
    return true;
  }

  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.wasInvited(userId);
});
