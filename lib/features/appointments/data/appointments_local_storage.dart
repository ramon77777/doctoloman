import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';

class AppointmentsLocalStorage {
  AppointmentsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _appointmentsKey = 'appointments.items';

  Future<List<Appointment>> readAll() async {
    final raw = _prefs.getString(_appointmentsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Appointment>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Appointment>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Appointment.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return <Appointment>[];
    }
  }

  Future<void> saveAll(List<Appointment> appointments) async {
    final payload = appointments.map((e) => e.toMap()).toList();
    await _prefs.setString(_appointmentsKey, jsonEncode(payload));
  }

  Future<void> clear() async {
    await _prefs.remove(_appointmentsKey);
  }
}