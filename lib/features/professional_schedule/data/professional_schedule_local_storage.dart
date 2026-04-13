import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/professional_schedule.dart';

class ProfessionalScheduleLocalStorage {
  ProfessionalScheduleLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'professional_schedules_v3';

  Future<Map<String, List<DaySchedule>>> readAll() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<DaySchedule>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, List<DaySchedule>>{};
      }

      final result = <String, List<DaySchedule>>{};

      decoded.forEach((key, value) {
        final normalizedPractitionerId = key.trim();
        if (normalizedPractitionerId.isEmpty) return;
        if (value is! List) return;

        final days = <DaySchedule>[];

        for (final entry in value) {
          if (entry is! Map) continue;

          try {
            final day = DaySchedule.fromMap(
              Map<String, dynamic>.from(entry),
            );
            days.add(day);
          } catch (_) {
            // Ignore uniquement l'entrée invalide.
          }
        }

        if (days.isNotEmpty) {
          result[normalizedPractitionerId] =
              List<DaySchedule>.unmodifiable(days);
        }
      });

      return Map<String, List<DaySchedule>>.unmodifiable(result);
    } catch (_) {
      return <String, List<DaySchedule>>{};
    }
  }

  Future<void> writeAll(Map<String, List<DaySchedule>> data) async {
    final payload = <String, dynamic>{
      for (final entry in data.entries)
        entry.key: entry.value.map((day) => day.toMap()).toList(),
    };

    await _prefs.setString(storageKey, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}