import 'package:fieldawy_store/features/jobs/data/job_offers_repository.dart';
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jobOffersRepositoryProvider = Provider<JobOffersRepository>((ref) {
  return JobOffersRepository();
});

final allJobOffersProvider = FutureProvider<List<JobOffer>>((ref) async {
  final repository = ref.watch(jobOffersRepositoryProvider);
  return repository.getAllJobOffers();
});

final myJobOffersProvider = FutureProvider<List<JobOffer>>((ref) async {
  final repository = ref.watch(jobOffersRepositoryProvider);
  return repository.getMyJobOffers();
});

class JobOffersNotifier extends StateNotifier<AsyncValue<List<JobOffer>>> {
  final JobOffersRepository _repository;

  JobOffersNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchAllJobs();
  }

  Future<void> fetchAllJobs() async {
    state = const AsyncValue.loading();
    try {
      final jobs = await _repository.getAllJobOffers();
      state = AsyncValue.data(jobs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refreshAllJobs() async {
    await fetchAllJobs();
  }
}

final allJobOffersNotifierProvider = StateNotifierProvider<JobOffersNotifier, AsyncValue<List<JobOffer>>>((ref) {
  final repository = ref.watch(jobOffersRepositoryProvider);
  return JobOffersNotifier(repository);
});

class MyJobOffersNotifier extends StateNotifier<AsyncValue<List<JobOffer>>> {
  final JobOffersRepository _repository;

  MyJobOffersNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchMyJobs();
  }

  Future<void> fetchMyJobs() async {
    state = const AsyncValue.loading();
    try {
      final jobs = await _repository.getMyJobOffers();
      state = AsyncValue.data(jobs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refreshMyJobs() async {
    await fetchMyJobs();
  }

  Future<bool> deleteJob(String jobId) async {
    try {
      await _repository.deleteJobOffer(jobId);
      await fetchMyJobs();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> closeJob(String jobId) async {
    try {
      await _repository.closeJobOffer(jobId);
      await fetchMyJobs();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final myJobOffersNotifierProvider = StateNotifierProvider<MyJobOffersNotifier, AsyncValue<List<JobOffer>>>((ref) {
  final repository = ref.watch(jobOffersRepositoryProvider);
  return MyJobOffersNotifier(repository);
});
