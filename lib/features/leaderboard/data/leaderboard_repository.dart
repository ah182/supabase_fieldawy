import 'package:fieldawy_store/features/leaderboard/domain/season_model.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  Future<List<UserModel>> getLeaderboard() async {
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

      return users;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  Future<String?> getClaimedPrize(String userId) async {
    try {
      final response = await _client
          .from('claimed_prizes')
          .select('prize_won')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }
      return response['prize_won'] as String?;
    } catch (e) {
      print('Error fetching claimed prize: $e');
      rethrow;
    }
  }

  Future<void> claimPrize(String userId, String prize) async {
    try {
      await _client.from('claimed_prizes').insert({
        'user_id': userId,
        'prize_won': prize,
      });
    } catch (e) {
      print('Error claiming prize: $e');
      rethrow;
    }
  }

  Future<LeaderboardSeason?> getCurrentSeason() async {
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
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final client = Supabase.instance.client;
  return LeaderboardRepository(client);
});
