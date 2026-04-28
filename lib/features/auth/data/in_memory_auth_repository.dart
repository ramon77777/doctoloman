import '../../../core/models/app_user.dart';
import '../domain/auth_repository.dart';
import 'auth_local_storage.dart';

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._localStorage) {
    _currentUser = _localStorage.getCurrentUser();
    _loggedIn = _localStorage.isLoggedIn && _currentUser != null;
  }

  final AuthLocalStorage _localStorage;

  bool _loggedIn = false;
  AppUser? _currentUser;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<void> login(AppUser user) async {
    _loggedIn = true;
    _currentUser = user;

    await _localStorage.saveUser(user);
    await _localStorage.saveSession(user);
  }

  @override
  Future<void> register(AppUser user) async {
    await _localStorage.saveUser(user);
    await login(user);
  }

  @override
  Future<void> updateUser(AppUser user) async {
    if (!_loggedIn || _currentUser == null) return;

    _currentUser = user;

    await _localStorage.saveUser(user);
    await _localStorage.saveSession(user);
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
    _currentUser = null;

    await _localStorage.clearSession();
  }

  @override
  Future<AppUser?> findByPhone(String phone) {
    return _localStorage.findByPhone(phone);
  }

  @override
  Future<List<AppUser>> getAllUsers() {
    return _localStorage.getAllUsers();
  }
}