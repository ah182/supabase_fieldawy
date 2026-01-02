import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardFiltersState {
  final bool isNearest;
  final String? selectedGovernorate;

  const LeaderboardFiltersState({
    this.isNearest = false,
    this.selectedGovernorate,
  });

  LeaderboardFiltersState copyWith({
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false,
  }) {
    return LeaderboardFiltersState(
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class LeaderboardFiltersNotifier extends StateNotifier<LeaderboardFiltersState> {
  LeaderboardFiltersNotifier() : super(const LeaderboardFiltersState());

  void toggleNearest() {
    if (!state.isNearest) {
      state = state.copyWith(isNearest: true, clearGovernorate: true);
    } else {
      state = state.copyWith(isNearest: false);
    }
  }

  void setGovernorate(String? governorate) {
    if (governorate != null) {
      state = state.copyWith(selectedGovernorate: governorate, isNearest: false);
    } else {
      state = state.copyWith(clearGovernorate: true);
    }
  }

  void resetFilters() {
    state = const LeaderboardFiltersState();
  }
}

final leaderboardFiltersProvider = StateNotifierProvider<LeaderboardFiltersNotifier, LeaderboardFiltersState>((ref) {
  return LeaderboardFiltersNotifier();
});
