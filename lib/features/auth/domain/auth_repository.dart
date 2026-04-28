import '../../../core/models/app_user.dart';

abstract class AuthRepository {
  bool get isLoggedIn;

  AppUser? get currentUser;

  Future<void> login(AppUser user);

  Future<void> register(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<void> logout();

  Future<AppUser?> findByPhone(String phone);

  Future<List<AppUser>> getAllUsers();
}