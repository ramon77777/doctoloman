import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/auth_local_storage.dart';
import '../../data/in_memory_auth_repository.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_state.dart';
import 'auth_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not initialized'),
  name: 'sharedPreferencesProvider',
);

final authLocalStorageProvider = Provider<AuthLocalStorage>(
  (ref) => AuthLocalStorage(ref.watch(sharedPreferencesProvider)),
  name: 'authLocalStorageProvider',
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => InMemoryAuthRepository(ref.watch(authLocalStorageProvider)),
  name: 'authRepositoryProvider',
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
  name: 'authControllerProvider',
);

final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isAuthenticated,
  name: 'isLoggedInProvider',
);