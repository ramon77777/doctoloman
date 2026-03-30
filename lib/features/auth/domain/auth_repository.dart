import '../../../core/models/app_user.dart';

abstract class AuthRepository {
  bool get isLoggedIn;

  AppUser? get currentUser;

  Future<void> setLoggedIn(bool value);

  Future<void> login(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<void> logout();
}