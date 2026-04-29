import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/teleconsultation_session.dart';

class TeleconsultationLocalStorage {
  TeleconsultationLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _storageKey = 'doctoloman.teleconsultations.v1';

  Future<List<TeleconsultationSession>> readAll() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <TeleconsultationSession>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <TeleconsultationSession>[];
      }

      final sessions = <TeleconsultationSession>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          sessions.add(TeleconsultationSession.fromMap(item));
        } else if (item is Map) {
          sessions.add(
            TeleconsultationSession.fromMap(
              item.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }
      }

      sessions.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return List<TeleconsultationSession>.unmodifiable(sessions);
    } catch (_) {
      return const <TeleconsultationSession>[];
    }
  }

  Future<void> writeAll(List<TeleconsultationSession> sessions) async {
    final normalized = [...sessions]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final encoded = jsonEncode(
      normalized.map((session) => session.toMap()).toList(),
    );

    await _prefs.setString(_storageKey, encoded);
  }

  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }
}