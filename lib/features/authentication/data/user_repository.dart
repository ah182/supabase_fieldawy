// ignore_for_file: unnecessary_type_check

import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
// ignore: unused_import
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_model.dart'; 
import 'dart:async';

class UserRepository {
  final SupabaseClient _client;
  final CachingService _cache;

  UserRepository({required SupabaseClient client, required CachingService cache})
      : _client = client,
        _cache = cache;

  Future<bool> saveNewUser(User user) async {
    return await NetworkGuard.execute(() async {
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

        await _client.from('users').insert(userMap);
        if (userMap['role'] == 'distributor' || userMap['role'] == 'company') {
          _cache.invalidate('distributors');
        }
        return true; 
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          print('User with ID ${user.id} already exists in DB. Skipping insert.');
          return false; 
        } else {
          print('Error saving new user to Supabase: $e');
          rethrow;
        }
      } catch (e) {
        print('Error saving new user to Supabase: $e');
        rethrow;
      }
    });
  }

  Future<void> completeUserProfile({
    required String id,
    required String role,
    required String documentUrl,
    required String displayName,
    required String whatsappNumber,
    required List<String> governorates,
    required List<String> centers,
    String? distributionMethod,
    String? photoUrl,
  }) async {
    await NetworkGuard.execute(() async {
      try {
        final updateData = {
          'id': id,
          'role': role,
          'document_url': documentUrl,
          'display_name': displayName,
          'whatsapp_number': whatsappNumber,
          'governorates': governorates,
          'centers': centers,
          'is_profile_complete': true,
          'email': _client.auth.currentUser?.email, // Ensure email is present for new rows
          'account_status': 'pending_review', // Default status for new profiles
        };

        if (distributionMethod != null) {
          updateData['distribution_method'] = distributionMethod;
        }

        if (photoUrl != null) {
          updateData['photo_url'] = photoUrl;
        }

        // Use upsert to create the user record if it doesn't exist (deferred save) or update if it does.
        await _client.from('users').upsert(updateData);
        _cache.invalidate('distributors');
        _cache.invalidate('user_$id');

      } catch (e) {
        print('Error completing user profile in Supabase: $e');
        rethrow;
      }
    });
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
    await NetworkGuard.execute(() async {
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
    });
  }

  Future<void> updateProfileImage(String userId, String photoUrl) async {
    await NetworkGuard.execute(() async {
      try {
        await _client.from('users').update({
          'photo_url': photoUrl,
        }).eq('id', userId);
        
        _cache.invalidate('user_$userId');
      } catch (e) {
        print('Error updating profile image in Supabase: $e');
        rethrow;
      }
    });
  }

  Future<void> linkUserIdentity({
    required String id,
    required String email,
    required String password,
  }) async {
    // This updates the Auth user (not just the public.users table)
    // Note: This operation is usually done via client auth update
    // But we might need to update the public.users table email field too
    await NetworkGuard.execute(() async {
      try {
        await _client.from('users').update({
          'email': email,
        }).eq('id', id);
        _cache.invalidate('user_$id');
      } catch (e) {
        print('Error linking user identity in DB: $e');
        // We don't rethrow here because the critical part is the Auth update which happens in AuthService
      }
    });
  }

  Future<UserModel?> getUser(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'user_$id';
    UserModel? cachedUser;
    
    if (!forceRefresh) {
      cachedUser = _cache.get<UserModel>(cacheKey);
      if (cachedUser != null && cachedUser.referralCode != null) {
        return cachedUser;
      }
    }

    return await NetworkGuard.execute(() async {
      try {
        if (id.isEmpty) return null;

        final response = await _client
            .from('users')
            .select('*, clinics(clinic_code, latitude, longitude)')
            .eq('id', id)
            .maybeSingle();

        if (response == null) return null;

        final Map<String, dynamic> data = Map<String, dynamic>.from(response);
        if (response['clinics'] != null) {
          final List clinics = response['clinics'] is List ? response['clinics'] : [response['clinics']];
          if (clinics.isNotEmpty) {
            final clinicData = clinics[0];
            data['clinic_code'] = clinicData['clinic_code'];
            data['last_latitude'] = data['last_latitude'] ?? clinicData['latitude'];
            data['last_longitude'] = data['last_longitude'] ?? clinicData['longitude'];
          }
        }

        var user = UserModel.fromMap(data);

        if (user.referralCode == null || user.referralCode!.isEmpty) {
          final newCode = await _client.rpc('generate_and_get_code', params: {'user_id_param': user.id}) as String?;
          if (newCode != null) {
            user = user.copyWith(referralCode: newCode);
          }
        }

        _cache.set(cacheKey, user);
        return user;
      } catch (e) {
        print('Error fetching user data: $e');
        if (cachedUser != null) return cachedUser;
        rethrow;
      }
    });
  }

  Future<void> reInitiateOnboarding(String id) async {
    await NetworkGuard.execute(() async {
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
    });
  }

  Future<int> getTotalUsersCount() async {
    return await NetworkGuard.execute(() async {
      try {
        final count = await _client.from('users').count(CountOption.exact);
        return count;
      } catch (e) {
        print('Error counting users: $e');
        return 0;
      }
    });
  }

  Future<int> getUsersCountByRole(String role) async {
    return await NetworkGuard.execute(() async {
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
    });
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    return await _cache.cacheFirst<List<UserModel>>(
      key: 'users_by_role_$role',
      duration: CacheDurations.medium,
      fetchFromNetwork: () => _fetchUsersByRole(role),
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => UserModel.fromMap(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<UserModel>> _fetchUsersByRole(String role) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client
            .from('users')
            .select()
            .eq('role', role)
            .order('created_at', ascending: false);
        final List<dynamic> data = response as List;
        _cache.set('users_by_role_$role', data, duration: CacheDurations.medium);
        return data.map((json) => UserModel.fromMap(json)).toList();
      } catch (e) {
        print('Error fetching users by role: $e');
        return [];
      }
    });
  }

  Future<List<UserModel>> getAllUsers({bool bypassCache = false}) async {
    if (bypassCache) return _fetchAllUsers();
    return await _cache.cacheFirst<List<UserModel>>(
      key: 'all_users',
      duration: CacheDurations.medium,
      fetchFromNetwork: _fetchAllUsers,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => UserModel.fromMap(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<UserModel>> _fetchAllUsers() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client
            .from('users')
            .select()
            .order('created_at', ascending: false);
        final List<dynamic> data = response as List;
        _cache.set('all_users', data, duration: CacheDurations.medium);
        return data.map((json) => UserModel.fromMap(json)).toList();
      } catch (e) {
        print('Error fetching all users: $e');
        return [];
      }
    });
  }

  Future<bool> deleteUser(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _client.rpc('delete_user_completely', params: {'user_id': userId});
        _invalidateUsersCache(userId);
        return true;
      } catch (e) {
        try {
          await _client.from('users').delete().eq('id', userId);
          _invalidateUsersCache(userId);
          return true;
        } catch (e2) {
          print('❌ Error deleting user: $e2');
          return false;
        }
      }
    });
  }

  Future<bool> updateUserRole(String userId, String newRole) async {
    return await NetworkGuard.execute(() async {
      try {
        await _client.from('users').update({'role': newRole}).eq('id', userId);
        _invalidateUsersCache(userId);
        return true;
      } catch (e) {
        print('Error updating user role: $e');
        return false;
      }
    });
  }

  Future<bool> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _client.rpc('update_user_location', params: {
          'p_user_id': userId,
          'p_latitude': latitude,
          'p_longitude': longitude,
        });
        _cache.invalidate('user_$userId');
        return true;
      } catch (e) {
        print('❌ Error updating user location: $e');
        return false;
      }
    });
  }

  Future<bool> updateUserStatus(String userId, String newStatus, {String? rejectionReason}) async {
    return await NetworkGuard.execute(() async {
      try {
        final Map<String, dynamic> updateData = {'account_status': newStatus};
        if (rejectionReason != null) updateData['rejection_reason'] = rejectionReason;
        else if (newStatus != 'rejected') updateData['rejection_reason'] = null;
        
        final response = await _client.from('users').update(updateData).eq('id', userId).select();
        _invalidateUsersCache(userId);
        return response is List && response.isNotEmpty;
      } catch (e) {
        print('❌ Error updating user status: $e');
        return false;
      }
    });
  }

  Future<bool> wasInvited(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client.from('referrals').select('id').eq('invited_id', userId).limit(1);
        return response.isNotEmpty;
      } catch (e) {
        print('Error checking if user was invited: $e');
        return true;
      }
    });
  }

  Future<void> incrementSubscribers(String userId) async {
    await NetworkGuard.execute(() async {
      try {
        await _client.rpc('increment_subscribers', params: {'user_id': userId});
      } catch (e) {
        await _manualUpdateSubscribers(userId, 1);
      }
    });
  }

  Future<void> decrementSubscribers(String userId) async {
    await NetworkGuard.execute(() async {
      try {
        await _client.rpc('decrement_subscribers', params: {'user_id': userId});
      } catch (e) {
        await _manualUpdateSubscribers(userId, -1);
      }
    });
  }

  Future<void> _manualUpdateSubscribers(String userId, int change) async {
    await NetworkGuard.execute(() async {
      try {
        final user = await _client.from('users').select('subscribers_count').eq('id', userId).single();
        final currentCount = (user['subscribers_count'] as int?) ?? 0;
        final newCount = (currentCount + change) < 0 ? 0 : (currentCount + change);
        await _client.from('users').update({'subscribers_count': newCount}).eq('id', userId);
      } catch (e) {
        print('Error manually updating subscribers: $e');
      }
    });
  }

  void _invalidateUsersCache(String? userId) {
    if (userId != null) _cache.invalidate('user_$userId');
    _cache.invalidate('all_users');
    _cache.invalidateWithPrefix('users_by_role_');
    _cache.invalidate('distributors');
    _cache.invalidate('doctors');
    print('🧹 Users cache invalidated');
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final supabaseClient = Supabase.instance.client;
  final cachingService = ref.watch(cachingServiceProvider);
  return UserRepository(client: supabaseClient, cache: cachingService);
});

final totalUsersProvider = FutureProvider<int>((ref) {
  return ref.watch(userRepositoryProvider).getTotalUsersCount();
});

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
  return ref.watch(userRepositoryProvider).getAllUsers(bypassCache: true);
});

final wasInvitedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final userId = authState.asData?.value?.id;
  if (userId == null) return true;
  return ref.watch(userRepositoryProvider).wasInvited(userId);
});