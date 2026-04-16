import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medical_access_audit.dart';

class MedicalAccessAuditLocalStorage {
  MedicalAccessAuditLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'medical_access.audit_items';

  Future<List<MedicalAccessAudit>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <MedicalAccessAudit>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MedicalAccessAudit>[];
      }

      final items = <MedicalAccessAudit>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          items.add(
            MedicalAccessAudit.fromMap(Map<String, dynamic>.from(entry)),
          );
        } catch (_) {
          // ignore entrée invalide
        }
      }

      return List<MedicalAccessAudit>.unmodifiable(items);
    } catch (_) {
      return const <MedicalAccessAudit>[];
    }
  }

  Future<void> saveAll(List<MedicalAccessAudit> items) async {
    final payload = items.map((item) => item.toMap()).toList(growable: false);
    await _prefs.setString(_key, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}