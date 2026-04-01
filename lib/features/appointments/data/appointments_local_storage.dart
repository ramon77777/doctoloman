import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';

class AppointmentsLocalStorage {
  AppointmentsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _appointmentsKey = 'appointments.items';

  Future<List<Appointment>> readAll() async {
    final raw = _prefs.getString(_appointmentsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Appointment>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Appointment>[];
      }

      final items = <Appointment>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;

        try {
          final appointment = Appointment.fromMap(
            Map<String, dynamic>.from(entry),
          );
          items.add(appointment);
        } catch (_) {
          // Ignore uniquement l'entrée invalide pour préserver le reste.
        }
      }

      return List<Appointment>.unmodifiable(items);
    } catch (_) {
      return const <Appointment>[];
    }
  }

  Future<void> saveAll(List<Appointment> appointments) async {
    final payload = appointments
        .map((appointment) => appointment.toMap())
        .toList(growable: false);

    await _prefs.setString(_appointmentsKey, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_appointmentsKey);
  }
}