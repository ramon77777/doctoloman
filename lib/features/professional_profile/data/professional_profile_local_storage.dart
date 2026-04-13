import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfessionalProfileLocalStorage {
  ProfessionalProfileLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'professional_profiles_v2';

  Map<String, dynamic> readProfilesMap() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // ignore
    }

    return <String, dynamic>{};
  }

  Future<void> writeProfilesMap(Map<String, dynamic> profilesMap) async {
    await _prefs.setString(
      storageKey,
      jsonEncode(profilesMap),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}