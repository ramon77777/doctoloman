import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medical_record.dart';

class MedicalRecordsLocalStorage {
  MedicalRecordsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'medical_records.items';

  Future<List<MedicalRecord>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return <MedicalRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <MedicalRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => MedicalRecord.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return <MedicalRecord>[];
    }
  }

  Future<void> saveAll(List<MedicalRecord> items) async {
    final payload = items.map((e) => e.toMap()).toList();
    await _prefs.setString(_key, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}