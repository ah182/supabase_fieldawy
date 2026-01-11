import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/application/product_interaction_service.dart';

class ProductInteractionState {
  final String? userInteraction; // 'like', 'dislike', or null
  final int likes;
  final int dislikes;

  ProductInteractionState({
    this.userInteraction,
    this.likes = 0,
    this.dislikes = 0,
  });

  ProductInteractionState copyWith({
    String? userInteraction,
    int? likes,
    int? dislikes,
  }) {
    return ProductInteractionState(
      userInteraction: userInteraction, // Allow setting to null
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
    );
  }
}

// State: Map<String, ProductInteractionState> where Key is "productId_distributorId"
class ProductInteractionNotifier extends StateNotifier<Map<String, ProductInteractionState>> {
  final ProductInteractionService _service;

  ProductInteractionNotifier(this._service) : super({});

  String _getKey(String productId, String distributorId) => '${productId}_$distributorId';

  Future<void> loadInteraction(String productId, String distributorId) async {
    final key = _getKey(productId, distributorId);
    if (state.containsKey(key)) return; // Already loaded

    // Fetch in parallel
    final interactionFuture = _service.getUserInteraction(productId, distributorId);
    final countsFuture = _service.getInteractionCounts(productId, distributorId);

    final results = await Future.wait([interactionFuture, countsFuture]);
    final interaction = results[0] as String?;
    final counts = results[1] as Map<String, int>;

    state = {
      ...state,
      key: ProductInteractionState(
        userInteraction: interaction,
        likes: counts['likes'] ?? 0,
        dislikes: counts['dislikes'] ?? 0,
      ),
    };
  }

  Future<void> toggleInteraction(String productId, String distributorId, String type) async {
    final key = _getKey(productId, distributorId);
    final currentState = state[key] ?? ProductInteractionState();
    final currentType = currentState.userInteraction;

    // Optimistic Update Logic
    String? newType;
    int newLikes = currentState.likes;
    int newDislikes = currentState.dislikes;

    if (currentType == type) {
      // Toggle OFF
      newType = null;
      if (type == 'like') newLikes = (newLikes - 1).clamp(0, 999999);
      if (type == 'dislike') newDislikes = (newDislikes - 1).clamp(0, 999999);
    } else {
      // Switch or Set
      newType = type;
      
      // If switching FROM something
      if (currentType == 'like') newLikes = (newLikes - 1).clamp(0, 999999);
      if (currentType == 'dislike') newDislikes = (newDislikes - 1).clamp(0, 999999);

      // If switching TO something
      if (type == 'like') newLikes++;
      if (type == 'dislike') newDislikes++;
    }

    // Apply Optimistic State
    state = {
      ...state,
      key: ProductInteractionState(
        userInteraction: newType,
        likes: newLikes,
        dislikes: newDislikes,
      ),
    };

    try {
      await _service.toggleInteraction(
        productId: productId,
        distributorId: distributorId,
        interactionType: type,
      );
    } catch (e) {
      // Revert on failure
      state = {...state, key: currentState};
      // ignore: avoid_print
      print('Failed to toggle interaction: $e');
    }
  }
}

final productInteractionProvider =
    StateNotifierProvider<ProductInteractionNotifier, Map<String, ProductInteractionState>>((ref) {
  final service = ref.watch(productInteractionServiceProvider);
  return ProductInteractionNotifier(service);
});
