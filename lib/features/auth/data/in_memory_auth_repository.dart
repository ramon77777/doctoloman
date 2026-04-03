import '../../../core/models/app_user.dart';
import '../domain/auth_repository.dart';
import 'auth_local_storage.dart';

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._localStorage) {
    _loggedIn = _localStorage.isLoggedIn;
    _currentUser = _localStorage.getCurrentUser();

    if (_currentUser == null) {
      _loggedIn = false;
    }
  }

  final AuthLocalStorage _localStorage;

  bool _loggedIn = false;
  AppUser? _currentUser;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<void> setLoggedIn(bool value) async {
    _loggedIn = value;

    if (!value) {
      _currentUser = null;
      await _localStorage.clearSession();
      return;
    }

    _currentUser ??= const AppUser(
      id: 'local-user',
      name: 'Utilisateur',
      phone: '+2250000000000',
      role: AppUserRole.patient,
    );

    await _localStorage.saveSession(_currentUser!);
  }

  @override
  Future<void> login(AppUser user) async {
    _loggedIn = true;
    _currentUser = user;
    await _localStorage.saveSession(user);
  }

  @override
  Future<void> updateUser(AppUser user) async {
    if (!_loggedIn) return;

    _currentUser = user;
    await _localStorage.saveSession(user);
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
    _currentUser = null;
    await _localStorage.clearSession();
  }
}