import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medical_record.dart';

class MedicalRecordsLocalStorage {
  MedicalRecordsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'medical_records.items';

  Future<List<MedicalRecord>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <MedicalRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MedicalRecord>[];
      }

      final items = <MedicalRecord>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          final record = MedicalRecord.fromMap(
            Map<String, dynamic>.from(entry),
          );
          items.add(record);
        } catch (_) {
          // Ignore uniquement l'entrée invalide pour préserver le reste.
        }
      }

      return List<MedicalRecord>.unmodifiable(items);
    } catch (_) {
      return const <MedicalRecord>[];
    }
  }

  Future<void> saveAll(List<MedicalRecord> items) async {
    final payload = items.map((item) => item.toMap()).toList(growable: false);
    await _prefs.setString(_key, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}