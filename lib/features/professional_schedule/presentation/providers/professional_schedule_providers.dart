import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/professional_schedule.dart';

const _professionalSchedulesStorageKey = 'professional_schedules_v1';

final practitionerScheduleProvider =
    Provider.family<List<DaySchedule>, String>((ref, practitionerId) {
  final schedulesByPractitioner = ref.watch(professionalSchedulesMapProvider);

  return schedulesByPractitioner[practitionerId] ??
      ProfessionalScheduleController.defaultSchedule;
}, name: 'practitionerScheduleProvider');

final professionalSchedulesMapProvider = StateNotifierProvider<
    ProfessionalScheduleController, Map<String, List<DaySchedule>>>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ProfessionalScheduleController(prefs);
  },
  name: 'professionalSchedulesMapProvider',
);

class ProfessionalScheduleController
    extends StateNotifier<Map<String, List<DaySchedule>>> {
  ProfessionalScheduleController(this._prefs) : super(_loadInitialState(_prefs));

  final SharedPreferences _prefs;

  static final List<DaySchedule> defaultSchedule = [
    const DaySchedule(
      weekday: 1,
      label: 'Lundi',
      isOpen: true,
      morningStart: '08:30',
      morningEnd: '12:00',
      afternoonStart: '14:00',
      afternoonEnd: '17:30',
    ),
    const DaySchedule(
      weekday: 2,
      label: 'Mardi',
      isOpen: true,
      morningStart: '08:30',
      morningEnd: '12:00',
      afternoonStart: '14:00',
      afternoonEnd: '17:30',
    ),
    const DaySchedule(
      weekday: 3,
      label: 'Mercredi',
      isOpen: true,
      morningStart: '08:30',
      morningEnd: '12:00',
      afternoonStart: '14:00',
      afternoonEnd: '17:30',
    ),
    const DaySchedule(
      weekday: 4,
      label: 'Jeudi',
      isOpen: true,
      morningStart: '08:30',
      morningEnd: '12:00',
      afternoonStart: '14:00',
      afternoonEnd: '17:30',
    ),
    const DaySchedule(
      weekday: 5,
      label: 'Vendredi',
      isOpen: true,
      morningStart: '08:30',
      morningEnd: '12:00',
      afternoonStart: '14:00',
      afternoonEnd: '17:00',
    ),
    const DaySchedule(
      weekday: 6,
      label: 'Samedi',
      isOpen: true,
      morningStart: '09:00',
      morningEnd: '12:00',
      afternoonStart: null,
      afternoonEnd: null,
    ),
    const DaySchedule(
      weekday: 7,
      label: 'Dimanche',
      isOpen: false,
      morningStart: null,
      morningEnd: null,
      afternoonStart: null,
      afternoonEnd: null,
    ),
  ];

  static Map<String, List<DaySchedule>> _loadInitialState(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_professionalSchedulesStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return {
        'pro_001': _cloneSchedule(defaultSchedule),
      };
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {
          'pro_001': _cloneSchedule(defaultSchedule),
        };
      }

      final result = <String, List<DaySchedule>>{};

      decoded.forEach((key, value) {
        if (key.trim().isEmpty) return;
        if (value is! List) return;

        final days = value
            .whereType<Map>()
            .map(
              (e) => DaySchedule.fromMap(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();

        if (days.isNotEmpty) {
          result[key] = _sortAndNormalize(days);
        }
      });

      if (!result.containsKey('pro_001')) {
        result['pro_001'] = _cloneSchedule(defaultSchedule);
      }

      return result;
    } catch (_) {
      return {
        'pro_001': _cloneSchedule(defaultSchedule),
      };
    }
  }

  List<DaySchedule> scheduleFor(String practitionerId) {
    final existing = state[practitionerId];
    if (existing != null) {
      return _cloneSchedule(existing);
    }
    return _cloneSchedule(defaultSchedule);
  }

  Future<void> toggleDay(String practitionerId, int weekday, bool open) async {
    final current = scheduleFor(practitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: open,
            clearMorning: !open,
            clearAfternoon: !open,
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(practitionerId, next);
  }

  Future<void> updateMorning({
    required String practitionerId,
    required int weekday,
    required String start,
    required String end,
  }) async {
    final current = scheduleFor(practitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            morningStart: start.trim(),
            morningEnd: end.trim(),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(practitionerId, next);
  }

  Future<void> updateAfternoon({
    required String practitionerId,
    required int weekday,
    required String start,
    required String end,
  }) async {
    final current = scheduleFor(practitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            afternoonStart: start.trim(),
            afternoonEnd: end.trim(),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(practitionerId, next);
  }

  Future<void> clearMorning(String practitionerId, int weekday) async {
    final current = scheduleFor(practitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(clearMorning: true)
        else
          day,
    ];

    await _replacePractitionerSchedule(practitionerId, next);
  }

  Future<void> clearAfternoon(String practitionerId, int weekday) async {
    final current = scheduleFor(practitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(clearAfternoon: true)
        else
          day,
    ];

    await _replacePractitionerSchedule(practitionerId, next);
  }

  Future<void> resetDefaults(String practitionerId) async {
    await _replacePractitionerSchedule(
      practitionerId,
      _cloneSchedule(defaultSchedule),
    );
  }

  Future<void> _replacePractitionerSchedule(
    String practitionerId,
    List<DaySchedule> next,
  ) async {
    state = {
      ...state,
      practitionerId: _sortAndNormalize(next),
    };
    await _persist();
  }

  Future<void> _persist() async {
    final payload = <String, dynamic>{
      for (final entry in state.entries)
        entry.key: entry.value.map((day) => day.toMap()).toList(),
    };

    await _prefs.setString(
      _professionalSchedulesStorageKey,
      jsonEncode(payload),
    );
  }

  static List<DaySchedule> _cloneSchedule(List<DaySchedule> input) {
    return input.map((day) => day.copyWith()).toList();
  }

  static List<DaySchedule> _sortAndNormalize(List<DaySchedule> input) {
    final sorted = [...input]..sort((a, b) => a.weekday.compareTo(b.weekday));
    return sorted;
  }
}