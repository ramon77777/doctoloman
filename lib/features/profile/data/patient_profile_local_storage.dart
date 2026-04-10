import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/patient_profile.dart';

class PatientProfileLocalStorage {
  PatientProfileLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _legacyKey = 'patient.profile';
  static const String _profilesKey = 'patient.profiles';

  Future<void> save(PatientProfile profile) async {
    final profiles = Map<String, PatientProfile>.from(readAll());

    final normalizedPhone = _normalizePhoneKey(profile.phone);
    if (normalizedPhone.isEmpty) {
      return;
    }

    profiles[normalizedPhone] = profile;
    await _persistProfiles(profiles);
  }

  PatientProfile? readByPhone(String phone) {
    final normalizedPhone = _normalizePhoneKey(phone);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    final profiles = readAll();
    return profiles[normalizedPhone];
  }

  Map<String, PatientProfile> readAll() {
    final raw = _prefs.getString(_profilesKey);
    final result = <String, PatientProfile>{};

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is! Map) return;

            try {
              final profile = PatientProfile.fromMap(
                Map<String, dynamic>.from(value),
              );
              final normalizedPhone = _normalizePhoneKey(profile.phone);
              if (normalizedPhone.isEmpty) return;

              result[normalizedPhone] = profile;
            } catch (_) {
              // Ignore uniquement l'entrée invalide.
            }
          });
        }
      } catch (_) {
        // Ignore et tente ensuite la migration legacy.
      }
    }

    if (result.isNotEmpty) {
      return Map<String, PatientProfile>.unmodifiable(result);
    }

    final legacy = _readLegacyProfile();
    if (legacy != null) {
      final normalizedPhone = _normalizePhoneKey(legacy.phone);
      if (normalizedPhone.isNotEmpty) {
        result[normalizedPhone] = legacy;
      }
    }

    return Map<String, PatientProfile>.unmodifiable(result);
  }

  Future<void> clearByPhone(String phone) async {
    final normalizedPhone = _normalizePhoneKey(phone);
    if (normalizedPhone.isEmpty) {
      return;
    }

    final profiles = Map<String, PatientProfile>.from(readAll());
    profiles.remove(normalizedPhone);
    await _persistProfiles(profiles);
  }

  Future<void> clear() async {
    await _prefs.remove(_profilesKey);
    await _prefs.remove(_legacyKey);
  }

  PatientProfile? _readLegacyProfile() {
    final raw = _prefs.getString(_legacyKey);
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

  Future<void> _persistProfiles(Map<String, PatientProfile> profiles) async {
    final payload = <String, dynamic>{
      for (final entry in profiles.entries) entry.key: entry.value.toMap(),
    };

    await _prefs.setString(_profilesKey, jsonEncode(payload));

    if (profiles.isNotEmpty) {
      final firstProfile = profiles.values.first;
      await _prefs.setString(_legacyKey, jsonEncode(firstProfile.toMap()));
    } else {
      await _prefs.remove(_legacyKey);
    }
  }

  String _normalizePhoneKey(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}