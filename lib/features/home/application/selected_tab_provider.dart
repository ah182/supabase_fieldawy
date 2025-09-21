import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the selected tab index in MainScaffold
final selectedTabProvider = StateProvider<int>((ref) {
  return 0; // Default to first tab (My Products for distributors)
});