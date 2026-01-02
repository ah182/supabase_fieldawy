import 'package:flutter_riverpod/flutter_riverpod.dart';

class DistributorFiltersState {
  final bool isNearest;
  final String? selectedGovernorate;

  const DistributorFiltersState({
    this.isNearest = false,
    this.selectedGovernorate,
  });

  DistributorFiltersState copyWith({
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false,
  }) {
    return DistributorFiltersState(
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class DistributorFiltersNotifier extends StateNotifier<DistributorFiltersState> {
  DistributorFiltersNotifier() : super(const DistributorFiltersState());

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
    state = const DistributorFiltersState();
  }
}

final distributorFiltersProvider = StateNotifierProvider<DistributorFiltersNotifier, DistributorFiltersState>((ref) {
  return DistributorFiltersNotifier();
});
