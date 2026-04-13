import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';

class AppointmentsLocalStorage {
  AppointmentsLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _appointmentsKey = 'appointments.items.v2';

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

          items.add(_safeNormalize(appointment));
        } catch (_) {
          // On ignore uniquement l'entrée corrompue
        }
      }

      return List<Appointment>.unmodifiable(items);
    } catch (_) {
      return const <Appointment>[];
    }
  }

  Future<void> saveAll(List<Appointment> appointments) async {
    final sanitized = appointments.map(_safeNormalize).toList(growable: false);

    final payload = sanitized
        .map((appointment) => appointment.toMap())
        .toList(growable: false);

    await _prefs.setString(
      _appointmentsKey,
      jsonEncode(payload),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_appointmentsKey);
  }

  /// 🔒 Sécurité anti-données corrompues / incohérentes
  Appointment _safeNormalize(Appointment a) {
    return a.copyWith(
      id: a.id.trim(),
      practitionerId: a.practitionerId.trim(),
      practitionerName: a.practitionerName.trim(),
      specialty: a.specialty.trim(),
      address: a.address.trim(),
      city: a.city.trim(),
      area: a.area.trim(),
      reason: a.reason.trim(),
      patientFirstName: a.patientFirstName.trim(),
      patientLastName: a.patientLastName.trim(),
      patientPhoneE164: a.patientPhoneE164.trim(),
      consentVersion: a.consentVersion.trim(),
      day: DateTime(a.day.year, a.day.month, a.day.day),
      slot: _normalizeSlot(a.slot),
    );
  }

  String _normalizeSlot(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split(':');
    if (parts.length != 2) return trimmed;

    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);

    if (hh == null || mm == null) return trimmed;

    return '${hh.clamp(0, 23).toString().padLeft(2, '0')}:${mm.clamp(0, 59).toString().padLeft(2, '0')}';
  }
}