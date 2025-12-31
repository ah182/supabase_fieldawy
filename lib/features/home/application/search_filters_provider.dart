import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchFiltersState {
  final bool isCheapest;
  final bool isNearest;
  final String? selectedGovernorate;

  const SearchFiltersState({
    this.isCheapest = false,
    this.isNearest = false,
    this.selectedGovernorate,
  });

  SearchFiltersState copyWith({
    bool? isCheapest,
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false, // خاصية لمسح المحافظة
  }) {
    return SearchFiltersState(
      isCheapest: isCheapest ?? this.isCheapest,
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class SearchFiltersNotifier extends StateNotifier<SearchFiltersState> {
  SearchFiltersNotifier() : super(const SearchFiltersState());

  void toggleCheapest() {
    state = state.copyWith(isCheapest: !state.isCheapest);
  }

  void toggleNearest() {
    if (!state.isNearest) {
      // عند تفعيل الأقرب، نلغي المحافظة المختارة
      state = state.copyWith(isNearest: true, clearGovernorate: true);
    } else {
      state = state.copyWith(isNearest: false);
    }
  }

  void setGovernorate(String? governorate) {
    if (governorate != null) {
      // عند اختيار محافظة، نلغي الأقرب
      state = state.copyWith(
        selectedGovernorate: governorate,
        isNearest: false,
      );
    } else {
      state = state.copyWith(clearGovernorate: true);
    }
  }

  void resetFilters() {
    state = const SearchFiltersState();
  }
}

final searchFiltersProvider = StateNotifierProvider<SearchFiltersNotifier, SearchFiltersState>((ref) {
  return SearchFiltersNotifier();
});
