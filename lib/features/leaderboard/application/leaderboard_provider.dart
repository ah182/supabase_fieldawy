import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fieldawy_store/features/leaderboard/domain/season_model.dart';

final leaderboardProvider = FutureProvider<List<UserModel>>((ref) {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return repository.getLeaderboard();
});

final claimedPrizeProvider = FutureProvider.autoDispose<String?>((ref) async {
  final userId = ref.watch(authStateChangesProvider).asData?.value?.id;
  if (userId == null) {
    return null;
  }
  final repository = ref.watch(leaderboardRepositoryProvider);
  return repository.getClaimedPrize(userId);
});

final currentSeasonProvider = FutureProvider<LeaderboardSeason?>((ref) {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return repository.getCurrentSeason();
});
