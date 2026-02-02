import 'dart:math';

import 'package:fieldawy_store/features/drug_ranking_gamification/domain/daily_challenge_model.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final drugRankingServiceProvider = Provider<DrugRankingService>((ref) {
  final productRepo = ref.read(productRepositoryProvider);
  return DrugRankingService(productRepo);
});

class DrugRankingService {
  final ProductRepository _productRepository;
  static const String _boxName = 'daily_ranking_challenge';

  DrugRankingService(this._productRepository);

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<DailyChallengeModel>(_boxName);
    }
  }

  Future<DailyChallengeModel?> getDailyChallenge() async {
    final box = Hive.box<DailyChallengeModel>(_boxName);
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    // Check if challenge already exists for today
    try {
      final existingChallenge = box.values.firstWhere((c) {
        final cDate = c.date;
        return "${cDate.year}-${cDate.month}-${cDate.day}" == todayStr;
      });

      // TEST MODE: Force NEW challenge generation every time
      /*
      if (existingChallenge.isCompleted) {
        return null; // Already done today
      }
      return existingChallenge;
      */

      // Delete existing challenge so we generate a FRESH one
      final key = box.keyAt(box.values.toList().indexOf(existingChallenge));
      await box.delete(key);

      // Fall through to generate new challenge...
    } catch (e) {
      // No challenge for today found, create one
    }

    // Generate new challenge
    // 1. Get all products
    print("🔍 DrugRankingService: Fetching all products...");
    final allProducts = await _productRepository.getAllProductsForRanking();
    print("🔍 DrugRankingService: Products fetched: ${allProducts.length}");

    if (allProducts.isEmpty) {
      print("🔍 DrugRankingService: No products found.");
      return null;
    }

    // Group by Active Principle
    final Map<String, List<ProductModel>> byActivePrinciple = {};
    for (var p in allProducts) {
      if (p.activePrinciple != null && p.package != null) {
        if (!byActivePrinciple.containsKey(p.activePrinciple!)) {
          byActivePrinciple[p.activePrinciple!] = [];
        }
        byActivePrinciple[p.activePrinciple!]!.add(p);
      }
    }
    print(
        "🔍 DrugRankingService: Grouped by Active Principle: ${byActivePrinciple.length} unique principles.");

    // Filter groups that have at least 4 products from DIFFERENT companies
    final List<Map<String, dynamic>> validCandidates = [];

    byActivePrinciple.forEach((principle, products) {
      // Group by package
      final Map<String, List<ProductModel>> byPackage = {};
      for (var p in products) {
        final pkg = p.package ?? "Unknown";
        if (!byPackage.containsKey(pkg)) {
          byPackage[pkg] = [];
        }
        byPackage[pkg]!.add(p);
      }

      byPackage.forEach((pkg, pkgProducts) {
        // Group by Company to ensure diversity
        final Map<String, List<ProductModel>> byCompany = {};
        for (var p in pkgProducts) {
          final company = p.company?.trim() ?? "Unknown";
          if (!byCompany.containsKey(company)) {
            byCompany[company] = [];
          }
          byCompany[company]!.add(p);
        }

        // We strictly need at least 4 DIFFERENT companies to avoid "Same company, diff concentration"
        if (byCompany.keys.length >= 4) {
          validCandidates.add({
            'activePrinciple': principle,
            'package': pkg,
            'products':
                pkgProducts, // We keep all, but will select carefully later
            'companies': byCompany,
          });
        }
      });
    });

    print(
        "🔍 DrugRankingService: Valid candidates found (Unique Companies >= 4): ${validCandidates.length}");

    if (validCandidates.isEmpty) {
      print("⚠️ No candidate groups with 4+ distinct companies found.");
      return null;
    }

    // Randomly select one candidate group
    final random = Random();
    final selection = validCandidates[random.nextInt(validCandidates.length)];
    final Map<String, List<ProductModel>> companyGroups =
        selection['companies'];

    // Select 4 random companies
    final companies = companyGroups.keys.toList();
    print(
        "🎲 Randomizing selection from ${companies.length} distinct companies...");
    companies.shuffle();
    final selectedCompanies = companies.take(4).toList();

    // From each selected company, pick 1 random product
    final List<ProductModel> challengeProducts = [];
    for (var company in selectedCompanies) {
      final companyProducts = companyGroups[company]!;
      challengeProducts
          .add(companyProducts[random.nextInt(companyProducts.length)]);
    }

    final newChallenge = DailyChallengeModel(
      id: const Uuid().v4(),
      date: today,
      products: challengeProducts,
      activePrinciple: selection['activePrinciple'],
      packageType: selection['package'],
    );

    await box.add(newChallenge);
    return newChallenge;
  }

  Future<void> submitRanking(
      DailyChallengeModel challenge, List<ProductModel> rankedProducts) async {
    final box = Hive.box<DailyChallengeModel>(_boxName);

    // Update local state
    challenge.isCompleted = true;
    challenge.isDismissedForNow = false;

    final key = box.keys
        .firstWhere((k) => box.get(k)?.id == challenge.id, orElse: () => null);
    if (key != null) {
      await box.put(key, challenge);
    }

    // Send ranking to Supabase
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final List<Map<String, dynamic>> votes = [];
        for (int i = 0; i < rankedProducts.length; i++) {
          votes.add({
            'user_id': user.id,
            'product_id': rankedProducts[i].id,
            'rank_position': i + 1, // 1-based rank (1 is best)
            'active_principle': challenge.activePrinciple,
            'package_type': challenge.packageType,
          });
        }
        await Supabase.instance.client.from('drug_ranking_votes').insert(votes);
        print("✅ Ranking submitted to Supabase successfully.");
      }
    } catch (e) {
      print("❌ Error submitting ranking to Supabase: $e");
      // TODO: Queue for offline sync if needed
    }
  }

  Future<void> dismissForLater(DailyChallengeModel challenge) async {
    final box = Hive.box<DailyChallengeModel>(_boxName);
    challenge.isDismissedForNow = true;
    final key = box.keys
        .firstWhere((k) => box.get(k)?.id == challenge.id, orElse: () => null);
    if (key != null) {
      await box.put(key, challenge);
    }
  }

  // Debug/Reset method
  Future<void> resetDailyChallenge() async {
    final box = Hive.box<DailyChallengeModel>(_boxName);
    await box.clear();
  }

  // Fetch all products with updated efficiency scores from Supabase
  Future<List<ProductModel>> getAllProductsForRankingWithScores() async {
    try {
      // 1. Fetch all products (Catalog)
      final products = await _productRepository.getAllProductsForRanking();

      // 2. Fetch global scores via RPC
      final List<dynamic> response =
          await Supabase.instance.client.rpc('get_drug_efficiency_scores');

      // Map scores for quick lookup: productId -> score
      final Map<String, double> scoreMap = {};
      for (var item in response) {
        if (item['product_id'] != null) {
          scoreMap[item['product_id'].toString()] =
              (item['efficiency_score'] as num).toDouble();
        }
      }

      // 3. Merge scores into products
      final List<ProductModel> productsWithScores = products.map((p) {
        final score = scoreMap[p.id];
        if (score != null) {
          return p.copyWith(efficiencyScore: score);
        }
        return p;
      }).toList();

      return productsWithScores;
    } catch (e) {
      print("Error fetching products with ranking scores: $e");
      // Fallback: return products without updated scores
      return await _productRepository.getAllProductsForRanking();
    }
  }

  // Temporary helper for the results screen until backend API is ready
  Future<List<ProductModel>> getAllProductsForRankingDebug() async {
    return getAllProductsForRankingWithScores();
  }
}
