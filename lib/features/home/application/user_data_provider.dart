import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/authentication/data/user_repository.dart';
import '../../../features/authentication/domain/user_model.dart';
import '../../../features/authentication/services/auth_service.dart';

final userDataProvider = FutureProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userId = authState.asData?.value?.id;

  if (userId == null) {
    return Future.value(null);
  }

  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUser(userId);
});
