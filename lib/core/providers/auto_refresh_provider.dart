import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fieldawy_store/core/providers/connectivity_provider.dart';
import 'package:fieldawy_store/core/utils/network_utils.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider that listens for connectivity changes and triggers a data refresh
/// when the app comes back online after being offline.
final autoRefreshProvider = Provider((ref) {
  ref.listen<AsyncValue<List<ConnectivityResult>>>(
    connectivityStatusProvider,
    (previous, next) {
      // Don't run on initial load
      if (previous == null || previous.isLoading) return;

      final wasOffline =
          previous.asData?.value.contains(ConnectivityResult.none) ?? true;
      final isOnline =
          next.asData?.value.contains(ConnectivityResult.none) == false;

      if (wasOffline && isOnline) {
        // We just came back online. Wait a bit for DNS to resolve, then refresh.
        Future.delayed(const Duration(seconds: 3), () async {
          bool hasInternet = false;
          for (int i = 0; i < 3; i++) {
            hasInternet = await hasRealInternet();
            if (hasInternet) break;
            await Future.delayed(const Duration(seconds: 3));
          }

          if (hasInternet) {
            // Invalidate all product-related providers by updating the last modified timestamp.
            ref.read(productDataLastModifiedProvider.notifier).state =
                DateTime.now();
            // Invalidate the user data provider separately.
            ref.invalidate(userDataProvider);
          }
        });
      }
    },
  );
});
