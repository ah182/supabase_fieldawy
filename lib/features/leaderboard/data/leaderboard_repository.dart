import 'package:fieldawy_store/features/leaderboard/domain/season_model.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardRepository {
  final SupabaseClient _client;
  final CachingService _cache;

  LeaderboardRepository(this._client, this._cache);

  Future<List<UserModel>> getLeaderboard() async {
    // إلغاء الكاش، الجلب مباشرة من الشبكة
    return await _fetchLeaderboard();
  }

  Future<List<UserModel>> _fetchLeaderboard() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client
            .from('users')
            .select()
            .order('points', ascending: false)
            .limit(100); // Limit to top 100 users

        final users = (response as List)
            .map((data) => UserModel.fromMap(data))
            .toList();

        // Assign ranks
        for (int i = 0; i < users.length; i++) {
          users[i] = users[i].copyWith(rank: i + 1);
        }

        // Cache as JSON List
        final jsonList = users.map((u) => u.toMap()).toList();
        _cache.set('leaderboard_top_100', jsonList, duration: CacheDurations.medium);

        return users;
      } catch (e) {
        print('Error fetching leaderboard: $e');
        rethrow;
      }
    });
  }

  Future<String?> getClaimedPrize(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        // First, get the ID of the most recently ended season
        final previousSeasonResponse = await _client
            .from('leaderboard_seasons')
            .select('id')
            .eq('is_active', false)
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (previousSeasonResponse == null) {
          // No previous season, so no prize could have been claimed for it
          return null;
        }
        final previousSeasonId = previousSeasonResponse['id'];

        // Now, check for a claimed prize for that specific season
        final response = await _client
            .from('claimed_prizes')
            .select('prize_won')
            .eq('user_id', userId)
            .eq('season_id', previousSeasonId)
            .maybeSingle();

        if (response == null) {
          return null;
        }
        return response['prize_won'] as String?;
      } catch (e) {
        print('Error fetching claimed prize: $e');
        rethrow;
      }
    });
  }

  Future<void> claimPrize(String userId, String prize) async {
    await NetworkGuard.execute(() async {
      try {
        await _client.rpc('claim_prize', params: {
          'p_user_id': userId,
          'p_prize_won': prize,
        });
      } catch (e) {
        print('Error claiming prize: $e');
        rethrow;
      }
    });
  }

  Future<LeaderboardSeason?> getCurrentSeason() async {
    // إلغاء الكاش، الجلب مباشرة من الشبكة
    return await _fetchCurrentSeason();
  }

  Future<LeaderboardSeason?> _fetchCurrentSeason() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client
            .from('leaderboard_seasons')
            .select()
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();

        if (response == null) {
          return null;
        }
        return LeaderboardSeason.fromMap(response);
      } catch (e) {
        print('Error fetching current season: $e');
        rethrow;
      }
    });
  }

  Future<int?> getPreviousSeasonWinnerRank(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        // 1. Find the most recently ended season
        final previousSeasonResponse = await _client
            .from('leaderboard_seasons')
            .select('id')
            .eq('is_active', false)
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (previousSeasonResponse == null) {
          return null; // No previous season
        }
        final previousSeasonId = previousSeasonResponse['id'];

        // 2. Fetch the rank for that specific season
        final response = await _client
            .from('season_rankings')
            .select('final_rank')
            .eq('user_id', userId)
            .eq('season_id', previousSeasonId)
            .maybeSingle();

        if (response == null) {
          return null;
        }
        return response['final_rank'] as int?;
      } catch (e) {
        print('Error fetching previous season rank: $e');
        rethrow;
      }
    });
  }

  Future<bool> isPrizeClaimWindowOpen() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _client
            .from('leaderboard_seasons')
            .select('start_date')
            .eq('is_active', true)
            .limit(1)
            .single();

        final startDate = DateTime.parse(response['start_date']);
        return DateTime.now().isBefore(startDate.add(const Duration(days: 30)));
      } catch (e) {
        print('Error checking prize claim window: $e');
        return false;
      }
    });
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final client = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  return LeaderboardRepository(client, cache);
});
