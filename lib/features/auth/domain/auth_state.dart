import '../../../core/models/app_user.dart';

class AuthState {
  final AppUser? user;
  final bool isLoading;

  const AuthState({
    this.user,
    this.isLoading = false,
  });

  bool get isAuthenticated => user != null;
  bool get isPatient => user?.isPatient ?? false;
  bool get isProfessional => user?.isProfessional ?? false;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState(
      user: null,
      isLoading: false,
    );
  }

  factory AuthState.loading({AppUser? user}) {
    return AuthState(
      user: user,
      isLoading: true,
    );
  }

  factory AuthState.authenticated(AppUser user) {
    return AuthState(
      user: user,
      isLoading: false,
    );
  }
}