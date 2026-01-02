import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobFiltersState {
  final bool isNearest;
  final String? selectedGovernorate;

  const JobFiltersState({
    this.isNearest = false,
    this.selectedGovernorate,
  });

  JobFiltersState copyWith({
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false,
  }) {
    return JobFiltersState(
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class JobFiltersNotifier extends StateNotifier<JobFiltersState> {
  JobFiltersNotifier() : super(const JobFiltersState());

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
    state = const JobFiltersState();
  }
}

final jobFiltersProvider = StateNotifierProvider<JobFiltersNotifier, JobFiltersState>((ref) {
  return JobFiltersNotifier();
});
