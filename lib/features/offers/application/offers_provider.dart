import 'package:fieldawy_store/features/offers/data/offers_repository.dart';
import 'package:fieldawy_store/features/offers/domain/offer_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository Provider is now defined in offers_repository.dart

// ===== ADMIN PROVIDERS =====

// Admin: Get all offers
final adminAllOffersProvider = FutureProvider<List<Offer>>((ref) async {
  final repository = ref.watch(offersRepositoryProvider);
  return repository.adminGetAllOffers();
});
