// ignore: unused_import
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
// ignore: unused_import

final authUserProvider = Provider((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userData = ref.watch(userDataProvider);
  return (authState, userData);
});
