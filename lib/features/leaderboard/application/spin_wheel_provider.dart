import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SpinWheelAvailability {
  available,
  notWinner,
  windowClosed,
  alreadyClaimed,
  loading,
  error,
}

class SpinWheelAvailabilityDetails {
  final SpinWheelAvailability availability;
  final int? rank;
  final String? claimedPrize;

  SpinWheelAvailabilityDetails({
    required this.availability,
    this.rank,
    this.claimedPrize,
  });
}

final spinWheelAvailabilityProvider = FutureProvider.autoDispose<SpinWheelAvailabilityDetails>((ref) async {
  final userId = ref.watch(authStateChangesProvider).asData?.value?.id;
  if (userId == null) {
    return SpinWheelAvailabilityDetails(availability: SpinWheelAvailability.error);
  }

  final leaderboardRepository = ref.watch(leaderboardRepositoryProvider);

  try {
    final claimedPrize = await leaderboardRepository.getClaimedPrize(userId);
    if (claimedPrize != null) {
      return SpinWheelAvailabilityDetails(
        availability: SpinWheelAvailability.alreadyClaimed,
        claimedPrize: claimedPrize,
      );
    }

    final isWindowOpen = await leaderboardRepository.isPrizeClaimWindowOpen();
    if (!isWindowOpen) {
      return SpinWheelAvailabilityDetails(availability: SpinWheelAvailability.windowClosed);
    }

    final winnerRank = await leaderboardRepository.getPreviousSeasonWinnerRank(userId);
    if (winnerRank == null || winnerRank > 5) {
      return SpinWheelAvailabilityDetails(availability: SpinWheelAvailability.notWinner);
    }

    return SpinWheelAvailabilityDetails(
      availability: SpinWheelAvailability.available,
      rank: winnerRank,
    );
  } catch (e) {
    return SpinWheelAvailabilityDetails(availability: SpinWheelAvailability.error);
  }
});
