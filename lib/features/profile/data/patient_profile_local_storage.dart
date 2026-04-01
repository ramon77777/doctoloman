import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/patient_profile.dart';

class PatientProfileLocalStorage {
  PatientProfileLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'patient.profile';

  Future<void> save(PatientProfile profile) async {
    final payload = jsonEncode(profile.toMap());
    await _prefs.setString(_key, payload);
  }

  PatientProfile? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      return PatientProfile.fromMap(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}