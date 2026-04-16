import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment_report.dart';

class AppointmentReportsLocalStorage {
  AppointmentReportsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'appointment_reports.items';

  Future<List<AppointmentReport>> readAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <AppointmentReport>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AppointmentReport>[];
      }

      final items = <AppointmentReport>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          items.add(
            AppointmentReport.fromMap(
              Map<String, dynamic>.from(entry),
            ),
          );
        } catch (_) {
          // ignore entry invalide
        }
      }

      return List<AppointmentReport>.unmodifiable(items);
    } catch (_) {
      return const <AppointmentReport>[];
    }
  }

  Future<void> saveAll(List<AppointmentReport> items) async {
    final payload = items.map((e) => e.toMap()).toList(growable: false);
    await _prefs.setString(_key, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}