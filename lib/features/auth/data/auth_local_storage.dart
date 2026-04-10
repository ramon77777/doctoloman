import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_user.dart';

class AuthLocalStorage {
  AuthLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _isLoggedInKey = 'auth.is_logged_in';
  static const _userJsonKey = 'auth.user_json';
  static const _usersKey = 'auth.users';

  Future<void> saveSession(AppUser user) async {
    final payload = jsonEncode(user.toMap());

    await _prefs.setBool(_isLoggedInKey, true);
    await _prefs.setString(_userJsonKey, payload);
  }

  Future<void> saveUser(AppUser user) async {
    final users = await getAllUsers();

    final normalizedPhone = _normalizePhoneKey(user.phone);
    final existingIndex = users.indexWhere(
      (item) => _normalizePhoneKey(item.phone) == normalizedPhone,
    );

    if (existingIndex >= 0) {
      users[existingIndex] = user;
    } else {
      users.add(user);
    }

    await _prefs.setString(
      _usersKey,
      jsonEncode(
        users.map((item) => item.toMap()).toList(growable: false),
      ),
    );
  }

  Future<List<AppUser>> getAllUsers() async {
    final raw = _prefs.getString(_usersKey);
    if (raw == null || raw.trim().isEmpty) {
      return <AppUser>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <AppUser>[];
      }

      final users = <AppUser>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          final user = AppUser.fromMap(Map<String, dynamic>.from(entry));
          if (user.id.isEmpty || user.phone.isEmpty) {
            continue;
          }
          users.add(user);
        } catch (_) {
          // Ignore seulement l'entrée invalide.
        }
      }

      return users;
    } catch (_) {
      return <AppUser>[];
    }
  }

  Future<AppUser?> findByPhone(String phone) async {
    final users = await getAllUsers();
    final normalizedPhone = _normalizePhoneKey(phone);

    if (normalizedPhone.isEmpty) {
      return null;
    }

    for (final user in users) {
      if (_normalizePhoneKey(user.phone) == normalizedPhone) {
        return user;
      }
    }

    return null;
  }

  bool get isLoggedIn {
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  AppUser? getCurrentUser() {
    final raw = _prefs.getString(_userJsonKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final user = AppUser.fromMap(map);

      if (user.id.isEmpty || user.name.isEmpty || user.phone.isEmpty) {
        return null;
      }

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _prefs.remove(_isLoggedInKey);
    await _prefs.remove(_userJsonKey);
  }

  String _normalizePhoneKey(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}