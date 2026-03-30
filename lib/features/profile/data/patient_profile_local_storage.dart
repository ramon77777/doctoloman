import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/patient_profile.dart';

class PatientProfileLocalStorage {
  PatientProfileLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'patient.profile';

  Future<void> save(PatientProfile profile) async {
    final json = jsonEncode(profile.toMap());
    await _prefs.setString(_key, json);
  }

  PatientProfile? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PatientProfile.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}