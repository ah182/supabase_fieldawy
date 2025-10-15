import 'package:fieldawy_store/features/surgical_tools/data/surgical_tools_repository.dart';
import 'package:fieldawy_store/features/surgical_tools/domain/surgical_tool_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository Provider
final surgicalToolsRepositoryProvider = Provider<SurgicalToolsRepository>((ref) {
  return SurgicalToolsRepository();
});

// ===== ADMIN PROVIDERS =====

// Admin: Get all surgical tools (catalog)
final adminAllSurgicalToolsProvider = FutureProvider<List<SurgicalTool>>((ref) async {
  final repository = ref.watch(surgicalToolsRepositoryProvider);
  return repository.adminGetAllSurgicalTools();
});

// Admin: Get all distributor surgical tools
final adminAllDistributorSurgicalToolsProvider = FutureProvider<List<DistributorSurgicalTool>>((ref) async {
  final repository = ref.watch(surgicalToolsRepositoryProvider);
  return repository.adminGetAllDistributorSurgicalTools();
});
