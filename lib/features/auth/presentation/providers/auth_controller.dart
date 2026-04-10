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
    required AppUserRole role,
  }) async {
    state = AuthState.loading(user: state.user);

    final normalizedName = StringNormalizers.collapseSpaces(name);
    final normalizedPhone = StringNormalizers.normalizePhoneCi(phone);

    final existingUser = await _repository.findByPhone(normalizedPhone);
    if (existingUser == null) {
      state = AuthState.unauthenticated();
      throw AuthLoginUserNotFoundException(phone: normalizedPhone);
    }

    if (existingUser.role != role) {
      state = AuthState.unauthenticated();
      throw AuthPhoneRoleMismatchException(
        phone: normalizedPhone,
        existingRole: existingUser.role,
        attemptedRole: role,
      );
    }

    final resolvedUser = existingUser.copyWith(
      name: normalizedName.isEmpty ? existingUser.name : normalizedName,
      phone: normalizedPhone,
    );

    await _repository.login(resolvedUser);
    state = AuthState.authenticated(resolvedUser);
  }

  Future<void> registerMock({
    required String name,
    required String phone,
    required AppUserRole role,
  }) async {
    state = AuthState.loading(user: state.user);

    final normalizedName = StringNormalizers.collapseSpaces(name);
    final normalizedPhone = StringNormalizers.normalizePhoneCi(phone);

    final existingUser = await _repository.findByPhone(normalizedPhone);
    if (existingUser != null) {
      state = AuthState.unauthenticated();
      throw AuthPhoneAlreadyUsedException(
        phone: normalizedPhone,
        existingRole: existingUser.role,
      );
    }

    final user = AppUser(
      id: _buildStableUserId(
        normalizedPhone: normalizedPhone,
        role: role,
      ),
      name: normalizedName.isEmpty ? 'Utilisateur' : normalizedName,
      phone: normalizedPhone,
      role: role,
    );

    await _repository.register(user);
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
      id: _buildStableUserId(
        normalizedPhone: normalizedPhone,
        role: currentUser.role,
      ),
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
          id: 'pat-2250000000000',
          name: 'Utilisateur',
          phone: '+2250000000000',
          role: AppUserRole.patient,
        );

    state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    state = AuthState.loading(user: state.user);
    await _repository.logout();
    state = AuthState.unauthenticated();
  }

  String _buildStableUserId({
    required String normalizedPhone,
    required AppUserRole role,
  }) {
    final digitsOnly = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    final prefix = role == AppUserRole.professional ? 'pro' : 'pat';

    if (digitsOnly.isEmpty) {
      return '$prefix-local-user';
    }

    return '$prefix-$digitsOnly';
  }
}

class AuthPhoneAlreadyUsedException implements Exception {
  const AuthPhoneAlreadyUsedException({
    required this.phone,
    required this.existingRole,
  });

  final String phone;
  final AppUserRole existingRole;

  @override
  String toString() {
    return 'AuthPhoneAlreadyUsedException(phone: $phone, existingRole: $existingRole)';
  }
}

class AuthLoginUserNotFoundException implements Exception {
  const AuthLoginUserNotFoundException({
    required this.phone,
  });

  final String phone;

  @override
  String toString() {
    return 'AuthLoginUserNotFoundException(phone: $phone)';
  }
}

class AuthPhoneRoleMismatchException implements Exception {
  const AuthPhoneRoleMismatchException({
    required this.phone,
    required this.existingRole,
    required this.attemptedRole,
  });

  final String phone;
  final AppUserRole existingRole;
  final AppUserRole attemptedRole;

  @override
  String toString() {
    return 'AuthPhoneRoleMismatchException('
        'phone: $phone, '
        'existingRole: $existingRole, '
        'attemptedRole: $attemptedRole'
        ')';
  }
}