import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medical_record.dart';

class MedicalRecordsLocalStorage {
  MedicalRecordsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _legacyKey = 'medical_records.items';
  static const String _recordsByPatientKey = 'medical_records.items_by_patient';

  Future<List<MedicalRecord>> readAllByPatient(String patientKey) async {
    final normalizedPatientKey = _normalizePatientKey(patientKey);
    if (normalizedPatientKey.isEmpty) {
      return const <MedicalRecord>[];
    }

    final recordsMap = _readAllRecordsMap();

    final items = recordsMap[normalizedPatientKey];
    if (items != null) {
      return List<MedicalRecord>.unmodifiable(items);
    }

    final legacyItems = _readLegacyRecords();
    if (legacyItems.isNotEmpty) {
      return List<MedicalRecord>.unmodifiable(legacyItems);
    }

    return const <MedicalRecord>[];
  }

  Future<void> saveAllByPatient(
    String patientKey,
    List<MedicalRecord> items,
  ) async {
    final normalizedPatientKey = _normalizePatientKey(patientKey);
    if (normalizedPatientKey.isEmpty) {
      return;
    }

    final recordsMap = Map<String, List<MedicalRecord>>.from(_readAllRecordsMap());
    recordsMap[normalizedPatientKey] = List<MedicalRecord>.unmodifiable(items);

    await _persistRecordsMap(recordsMap);
  }

  Future<void> clearByPatient(String patientKey) async {
    final normalizedPatientKey = _normalizePatientKey(patientKey);
    if (normalizedPatientKey.isEmpty) {
      return;
    }

    final recordsMap = Map<String, List<MedicalRecord>>.from(_readAllRecordsMap());
    recordsMap.remove(normalizedPatientKey);

    await _persistRecordsMap(recordsMap);
  }

  Future<void> clear() async {
    await _prefs.remove(_recordsByPatientKey);
    await _prefs.remove(_legacyKey);
  }

  Map<String, List<MedicalRecord>> _readAllRecordsMap() {
    final raw = _prefs.getString(_recordsByPatientKey);
    final result = <String, List<MedicalRecord>>{};

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            final normalizedPatientKey = _normalizePatientKey(key);
            if (normalizedPatientKey.isEmpty) return;
            if (value is! List) return;

            final items = <MedicalRecord>[];

            for (final entry in value) {
              if (entry is! Map) continue;

              try {
                final record = MedicalRecord.fromMap(
                  Map<String, dynamic>.from(entry),
                );
                items.add(record);
              } catch (_) {
                // Ignore uniquement l'entrée invalide.
              }
            }

            result[normalizedPatientKey] = List<MedicalRecord>.unmodifiable(items);
          });
        }
      } catch (_) {
        // Ignore et tente la lecture legacy plus bas si nécessaire.
      }
    }

    return Map<String, List<MedicalRecord>>.unmodifiable(result);
  }

  List<MedicalRecord> _readLegacyRecords() {
    final raw = _prefs.getString(_legacyKey);
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
          // Ignore uniquement l'entrée invalide.
        }
      }

      return List<MedicalRecord>.unmodifiable(items);
    } catch (_) {
      return const <MedicalRecord>[];
    }
  }

  Future<void> _persistRecordsMap(
    Map<String, List<MedicalRecord>> recordsMap,
  ) async {
    final payload = <String, dynamic>{
      for (final entry in recordsMap.entries)
        entry.key: entry.value
            .map((item) => item.toMap())
            .toList(growable: false),
    };

    await _prefs.setString(_recordsByPatientKey, jsonEncode(payload));

    if (recordsMap.isNotEmpty) {
      final firstItems = recordsMap.values.first;
      await _prefs.setString(
        _legacyKey,
        jsonEncode(
          firstItems.map((item) => item.toMap()).toList(growable: false),
        ),
      );
    } else {
      await _prefs.remove(_legacyKey);
    }
  }

  String _normalizePatientKey(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}