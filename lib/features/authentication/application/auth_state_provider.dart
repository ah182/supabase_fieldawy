import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';

final authGateStateProvider = Provider<AsyncValue<AuthGateState>>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return AsyncValue.data(AuthGateState.unauthenticated());
      }

      final userData = ref.watch(userDataProvider);
      return userData.when(
        data: (userModel) =>
            AsyncValue.data(AuthGateState.authenticated(userModel)),
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

class AuthGateState {
  final bool isAuthenticated;
  final dynamic userModel;

  const AuthGateState._({required this.isAuthenticated, this.userModel});

  factory AuthGateState.authenticated(dynamic userModel) =>
      AuthGateState._(isAuthenticated: true, userModel: userModel);

  factory AuthGateState.unauthenticated() =>
      const AuthGateState._(isAuthenticated: false);
}
