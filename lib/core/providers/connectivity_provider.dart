import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides an instance of the Connectivity service.
final connectivityServiceProvider = Provider((ref) => Connectivity());

/// A StateNotifier that holds the connectivity status.
/// It provides the initial status and updates on change.
class ConnectivityStatusNotifier
    extends StateNotifier<AsyncValue<List<ConnectivityResult>>> {
  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  ConnectivityStatusNotifier(this._connectivity)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      state = AsyncValue.data(result);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      state = AsyncValue.data(result);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider for the ConnectivityStatusNotifier.
final connectivityStatusProvider = StateNotifierProvider<
    ConnectivityStatusNotifier, AsyncValue<List<ConnectivityResult>>>((ref) {
  return ConnectivityStatusNotifier(ref.watch(connectivityServiceProvider));
});
