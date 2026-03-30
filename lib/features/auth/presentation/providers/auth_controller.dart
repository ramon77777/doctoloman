import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.unauthenticated()) {
    _bootstrap();
  }

  final AuthRepository _repository;

  void _bootstrap() {
    if (_repository.isLoggedIn && _repository.currentUser != null) {
      state = AuthState.authenticated(_repository.currentUser!);
      return;
    }

    state = AuthState.unauthenticated();
  }

  Future<void> loginMock({
    required String name,
    required String phone,
  }) async {
    state = AuthState.loading(user: state.user);

    final normalizedName = StringNormalizers.collapseSpaces(name);
    final normalizedPhone = StringNormalizers.normalizePhoneCi(phone);

    final user = AppUser(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      name: normalizedName.isEmpty ? 'Utilisateur' : normalizedName,
      phone: normalizedPhone,
    );

    await _repository.login(user);
    state = AuthState.authenticated(user);
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    state = AuthState.loading(user: currentUser);

    final normalizedName = StringNormalizers.collapseSpaces(name);
    final normalizedPhone = StringNormalizers.normalizePhoneCi(phone);

    final updatedUser = currentUser.copyWith(
      name: normalizedName.isEmpty ? currentUser.name : normalizedName,
      phone: normalizedPhone,
    );

    await _repository.updateUser(updatedUser);
    state = AuthState.authenticated(updatedUser);
  }

  Future<void> setLoggedIn(bool value) async {
    if (!value) {
      await _repository.logout();
      state = AuthState.unauthenticated();
      return;
    }

    state = AuthState.loading(user: state.user);

    await _repository.setLoggedIn(true);

    final user = _repository.currentUser ??
        const AppUser(
          id: 'local-user',
          name: 'Utilisateur',
          phone: '+2250000000000',
        );

    state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    state = AuthState.loading(user: state.user);
    await _repository.logout();
    state = AuthState.unauthenticated();
  }
}