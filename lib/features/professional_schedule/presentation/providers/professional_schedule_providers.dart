import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/professional_schedule.dart';

const _professionalSchedulesStorageKey = 'professional_schedules_v2';
const _defaultPractitionerId = 'pro_001';

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

  static final List<DaySchedule> defaultSchedule = List<DaySchedule>.unmodifiable(
    const [
      DaySchedule(
        weekday: 1,
        label: 'Lundi',
        isOpen: true,
        slots: [
          TimeSlot(start: '08:00', end: '08:15'),
          TimeSlot(start: '08:15', end: '08:30'),
          TimeSlot(start: '08:30', end: '08:45'),
          TimeSlot(start: '08:45', end: '09:00'),
          TimeSlot(start: '14:00', end: '14:15'),
          TimeSlot(start: '14:15', end: '14:30'),
        ],
      ),
      DaySchedule(
        weekday: 2,
        label: 'Mardi',
        isOpen: true,
        slots: [
          TimeSlot(start: '08:00', end: '08:15'),
          TimeSlot(start: '08:15', end: '08:30'),
          TimeSlot(start: '14:00', end: '14:15'),
          TimeSlot(start: '14:15', end: '14:30'),
        ],
      ),
      DaySchedule(
        weekday: 3,
        label: 'Mercredi',
        isOpen: true,
        slots: [
          TimeSlot(start: '08:30', end: '08:45'),
          TimeSlot(start: '08:45', end: '09:00'),
          TimeSlot(start: '09:00', end: '09:20'),
        ],
      ),
      DaySchedule(
        weekday: 4,
        label: 'Jeudi',
        isOpen: true,
        slots: [
          TimeSlot(start: '10:00', end: '10:20'),
          TimeSlot(start: '10:30', end: '10:50'),
          TimeSlot(start: '15:00', end: '15:30'),
        ],
      ),
      DaySchedule(
        weekday: 5,
        label: 'Vendredi',
        isOpen: true,
        slots: [
          TimeSlot(start: '08:10', end: '08:18'),
          TimeSlot(start: '08:20', end: '08:35'),
          TimeSlot(start: '09:00', end: '09:12'),
        ],
      ),
      DaySchedule(
        weekday: 6,
        label: 'Samedi',
        isOpen: true,
        slots: [
          TimeSlot(start: '09:00', end: '09:20'),
          TimeSlot(start: '09:30', end: '09:50'),
        ],
      ),
      DaySchedule(
        weekday: 7,
        label: 'Dimanche',
        isOpen: false,
        slots: [],
      ),
    ],
  );

  static Map<String, List<DaySchedule>> _loadInitialState(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_professionalSchedulesStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return _defaultState();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _defaultState();
      }

      final result = <String, List<DaySchedule>>{};

      decoded.forEach((key, value) {
        final normalizedPractitionerId = _normalizePractitionerId(key);
        if (normalizedPractitionerId.isEmpty) return;
        if (value is! List) return;

        final days = <DaySchedule>[];

        for (final entry in value) {
          if (entry is! Map) continue;

          try {
            final day = DaySchedule.fromMap(Map<String, dynamic>.from(entry));
            days.add(day);
          } catch (_) {
            // Ignore uniquement l'entrée invalide.
          }
        }

        if (days.isNotEmpty) {
          result[normalizedPractitionerId] = _sortAndNormalize(days);
        }
      });

      if (!result.containsKey(_defaultPractitionerId)) {
        result[_defaultPractitionerId] = _cloneSchedule(defaultSchedule);
      }

      return Map<String, List<DaySchedule>>.unmodifiable(result);
    } catch (_) {
      return _defaultState();
    }
  }

  List<DaySchedule> scheduleFor(String practitionerId) {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    if (normalizedPractitionerId.isEmpty) {
      return _cloneSchedule(defaultSchedule);
    }

    final existing = state[normalizedPractitionerId];
    if (existing != null) {
      return _cloneSchedule(existing);
    }

    return _cloneSchedule(defaultSchedule);
  }

  Future<void> toggleDay(String practitionerId, int weekday, bool open) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: open,
            clearSlots: !open,
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> addSlot({
    required String practitionerId,
    required int weekday,
    required TimeSlot slot,
  }) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            slots: sortTimeSlots([...day.slots, slot]),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> updateSlot({
    required String practitionerId,
    required int weekday,
    required int slotIndex,
    required TimeSlot slot,
  }) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            slots: _replaceSlot(day.slots, slotIndex, slot),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> removeSlot({
    required String practitionerId,
    required int weekday,
    required int slotIndex,
  }) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            slots: _removeSlot(day.slots, slotIndex),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> resetDefaults(String practitionerId) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    await _replacePractitionerSchedule(
      normalizedPractitionerId,
      _cloneSchedule(defaultSchedule),
    );
  }

  Future<void> _replacePractitionerSchedule(
    String practitionerId,
    List<DaySchedule> next,
  ) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    if (normalizedPractitionerId.isEmpty) return;

    final normalizedSchedule = _sortAndNormalize(next);

    final nextState = Map<String, List<DaySchedule>>.from(state)
      ..[normalizedPractitionerId] = normalizedSchedule;

    state = Map<String, List<DaySchedule>>.unmodifiable(nextState);
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

  static Map<String, List<DaySchedule>> _defaultState() {
    return Map<String, List<DaySchedule>>.unmodifiable({
      _defaultPractitionerId: _cloneSchedule(defaultSchedule),
    });
  }

  static String _normalizePractitionerId(String value) {
    return value.trim();
  }

  static List<DaySchedule> _cloneSchedule(List<DaySchedule> input) {
    return List<DaySchedule>.unmodifiable(
      input
          .map(
            (day) => day.copyWith(
              slots: List<TimeSlot>.unmodifiable(
                day.slots.map((slot) => slot.copyWith()).toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  static List<DaySchedule> _sortAndNormalize(List<DaySchedule> input) {
    final sorted = [...input]..sort((a, b) => a.weekday.compareTo(b.weekday));

    final deduplicatedByWeekday = <int, DaySchedule>{};
    for (final day in sorted) {
      deduplicatedByWeekday[day.weekday] = day.copyWith(
        slots: sortTimeSlots(day.slots),
      );
    }

    return List<DaySchedule>.unmodifiable(
      deduplicatedByWeekday.values.toList()
        ..sort((a, b) => a.weekday.compareTo(b.weekday)),
    );
  }

  static List<TimeSlot> _replaceSlot(
    List<TimeSlot> slots,
    int slotIndex,
    TimeSlot slot,
  ) {
    if (slotIndex < 0 || slotIndex >= slots.length) {
      return sortTimeSlots(slots);
    }

    final updated = [...slots];
    updated[slotIndex] = slot;
    return sortTimeSlots(updated);
  }

  static List<TimeSlot> _removeSlot(
    List<TimeSlot> slots,
    int slotIndex,
  ) {
    if (slotIndex < 0 || slotIndex >= slots.length) {
      return sortTimeSlots(slots);
    }

    final updated = [...slots]..removeAt(slotIndex);
    return sortTimeSlots(updated);
  }
}