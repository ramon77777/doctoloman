import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_user.dart';

class AuthLocalStorage {
  AuthLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _isLoggedInKey = 'auth.is_logged_in';
  static const _userJsonKey = 'auth.user_json';

  Future<void> saveSession(AppUser user) async {
    final payload = jsonEncode(user.toMap());

    await _prefs.setBool(_isLoggedInKey, true);
    await _prefs.setString(_userJsonKey, payload);
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
}