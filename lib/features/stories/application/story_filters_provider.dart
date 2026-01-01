import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoryFiltersState {
  final bool isNearest;
  final String? selectedGovernorate;

  const StoryFiltersState({
    this.isNearest = false,
    this.selectedGovernorate,
  });

  StoryFiltersState copyWith({
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false,
  }) {
    return StoryFiltersState(
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class StoryFiltersNotifier extends StateNotifier<StoryFiltersState> {
  StoryFiltersNotifier() : super(const StoryFiltersState());

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
    state = const StoryFiltersState();
  }
}

final storyFiltersProvider = StateNotifierProvider<StoryFiltersNotifier, StoryFiltersState>((ref) {
  return StoryFiltersNotifier();
});
