import 'package:flutter_riverpod/flutter_riverpod.dart';

class VetSuppliesFiltersState {
  final bool isCheapest; // Added
  final bool isNearest;
  final String? selectedGovernorate;

  const VetSuppliesFiltersState({
    this.isCheapest = false, // Added
    this.isNearest = false,
    this.selectedGovernorate,
  });

  VetSuppliesFiltersState copyWith({
    bool? isCheapest, // Added
    bool? isNearest,
    String? selectedGovernorate,
    bool clearGovernorate = false,
  }) {
    return VetSuppliesFiltersState(
      isCheapest: isCheapest ?? this.isCheapest, // Added
      isNearest: isNearest ?? this.isNearest,
      selectedGovernorate: clearGovernorate ? null : (selectedGovernorate ?? this.selectedGovernorate),
    );
  }
}

class VetSuppliesFiltersNotifier extends StateNotifier<VetSuppliesFiltersState> {
  VetSuppliesFiltersNotifier() : super(const VetSuppliesFiltersState());

  void toggleCheapest() { // Added
    state = state.copyWith(isCheapest: !state.isCheapest);
  }

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
    state = const VetSuppliesFiltersState();
  }
}

final vetSuppliesFiltersProvider = StateNotifierProvider<VetSuppliesFiltersNotifier, VetSuppliesFiltersState>((ref) {
  return VetSuppliesFiltersNotifier();
});
