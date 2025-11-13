import 'package:fieldawy_store/features/vet_supplies/data/vet_supplies_repository.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository Provider تم نقله إلى vet_supplies_repository.dart

// All Vet Supplies Notifier
class AllVetSuppliesNotifier extends StateNotifier<AsyncValue<List<VetSupply>>> {
  AllVetSuppliesNotifier(this.repository) : super(const AsyncValue.loading()) {
    refreshAllSupplies();
  }

  final VetSuppliesRepository repository;

  Future<void> refreshAllSupplies() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getAllVetSupplies());
  }

  // ✅ إضافة دالة زيادة المشاهدات
  Future<void> incrementViews(String id) async {
    await repository.incrementViews(id);
    
    // Update the views count in the current state
    state.whenData((supplies) {
      final index = supplies.indexWhere((s) => s.id == id);
      if (index != -1) {
        final updatedSupplies = List<VetSupply>.from(supplies);
        updatedSupplies[index] = supplies[index].copyWith(
          viewsCount: supplies[index].viewsCount + 1,
        );
        state = AsyncValue.data(updatedSupplies);
      }
    });
  }
}

final allVetSuppliesNotifierProvider =
    StateNotifierProvider<AllVetSuppliesNotifier, AsyncValue<List<VetSupply>>>((ref) {
  final repository = ref.watch(vetSuppliesRepositoryProvider);
  return AllVetSuppliesNotifier(repository);
});

// My Vet Supplies Notifier
class MyVetSuppliesNotifier extends StateNotifier<AsyncValue<List<VetSupply>>> {
  MyVetSuppliesNotifier(this.repository) : super(const AsyncValue.loading()) {
    refreshMySupplies();
  }

  final VetSuppliesRepository repository;

  Future<void> refreshMySupplies() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getMyVetSupplies());
  }

  Future<bool> deleteSupply(String id) async {
    try {
      await repository.deleteVetSupply(id);
      await refreshMySupplies();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Increment vet supply views - similar to job offers
  Future<void> incrementViews(String id) async {
    await repository.incrementViews(id);
    
    // Update the views count in the current state
    state.whenData((supplies) {
      final index = supplies.indexWhere((s) => s.id == id);
      if (index != -1) {
        final updatedSupplies = List<VetSupply>.from(supplies);
        updatedSupplies[index] = supplies[index].copyWith(
          viewsCount: supplies[index].viewsCount + 1,
        );
        state = AsyncValue.data(updatedSupplies);
      }
    });
  }
}

final myVetSuppliesNotifierProvider =
    StateNotifierProvider<MyVetSuppliesNotifier, AsyncValue<List<VetSupply>>>((ref) {
  final repository = ref.watch(vetSuppliesRepositoryProvider);
  return MyVetSuppliesNotifier(repository);
});

// ===== ADMIN PROVIDERS =====

// Admin: Get all vet supplies
final adminAllVetSuppliesProvider = FutureProvider<List<VetSupply>>((ref) async {
  final repository = ref.watch(vetSuppliesRepositoryProvider);
  return repository.adminGetAllVetSupplies();
});
