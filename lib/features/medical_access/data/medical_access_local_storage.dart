import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medical_access.dart';

class MedicalAccessLocalStorage {
  MedicalAccessLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'medical_access.items';

  Future<List<MedicalAccess>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <MedicalAccess>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MedicalAccess>[];
      }

      final items = <MedicalAccess>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          final access = MedicalAccess.fromMap(
            Map<String, dynamic>.from(entry),
          );
          items.add(access);
        } catch (_) {
          // Ignore uniquement l'entrée invalide.
        }
      }

      return List<MedicalAccess>.unmodifiable(items);
    } catch (_) {
      return const <MedicalAccess>[];
    }
  }

  Future<void> saveAll(List<MedicalAccess> items) async {
    final payload = items.map((item) => item.toMap()).toList(growable: false);
    await _prefs.setString(_key, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}