import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/notifications/data/notification_preferences_repository.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';

/// Provider for notification preferences (مع الكاش)
final notificationPreferencesProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final repository = ref.watch(notificationPreferencesRepositoryProvider);
  return await repository.getPreferences();
});

/// Provider for subscribed distributors (مع الكاش)
final subscribedDistributorsProvider =
    FutureProvider.autoDispose<List<DistributorModel>>((ref) async {
  final repository = ref.watch(notificationPreferencesRepositoryProvider);
  return await repository.getSubscribedDistributors();
});

/// State provider for manual refresh
final notificationRefreshProvider = StateProvider<int>((ref) => 0);
