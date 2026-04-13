import '../../domain/professional_schedule.dart';
import '../../domain/professional_schedule_repository.dart';
import '../datasources/professional_schedule_local_datasource.dart';
import '../datasources/professional_schedule_remote_datasource.dart';

const String defaultPractitionerId = 'pro_001';

final List<DaySchedule> defaultProfessionalSchedule =
    List<DaySchedule>.unmodifiable(
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

class ProfessionalScheduleRepositoryImpl
    implements ProfessionalScheduleRepository {
  ProfessionalScheduleRepositoryImpl({
    required ProfessionalScheduleLocalDataSource local,
    required ProfessionalScheduleRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final ProfessionalScheduleLocalDataSource _local;
  final ProfessionalScheduleRemoteDataSource _remote;

  Map<String, List<DaySchedule>>? _cache;

  @override
  Future<Map<String, List<DaySchedule>>> readAll({
    String? currentProfessionalId,
  }) async {
    _cache ??= await _local.readAll();

    final normalized = _normalizeState(
      _cache!,
      currentProfessionalId: currentProfessionalId,
    );

    _cache = normalized;
    await _local.writeAll(normalized);

    return _cloneState(normalized);
  }

  @override
  Future<List<DaySchedule>> scheduleFor(
    String practitionerId, {
    String? currentProfessionalId,
  }) async {
    final state = await readAll(currentProfessionalId: currentProfessionalId);
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);

    if (normalizedPractitionerId.isEmpty) {
      return _cloneSchedule(defaultProfessionalSchedule);
    }

    final existing = state[normalizedPractitionerId];
    if (existing != null && existing.isNotEmpty) {
      return _cloneSchedule(existing);
    }

    return _cloneSchedule(defaultProfessionalSchedule);
  }

  @override
  Future<Map<String, List<DaySchedule>>> replaceSchedule({
    required String practitionerId,
    required List<DaySchedule> schedule,
    String? currentProfessionalId,
  }) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    if (normalizedPractitionerId.isEmpty) {
      return readAll(currentProfessionalId: currentProfessionalId);
    }

    final current = await readAll(currentProfessionalId: currentProfessionalId);
    final next = Map<String, List<DaySchedule>>.from(current)
      ..[normalizedPractitionerId] = _sortAndNormalize(schedule);

    final normalizedNext = _normalizeState(
      next,
      currentProfessionalId: currentProfessionalId,
    );

    _cache = normalizedNext;
    await _remote.saveSchedule(
      practitionerId: normalizedPractitionerId,
      schedule: normalizedNext[normalizedPractitionerId] ??
          _cloneSchedule(defaultProfessionalSchedule),
    );
    await _local.writeAll(normalizedNext);

    return _cloneState(normalizedNext);
  }

  @override
  Future<Map<String, List<DaySchedule>>> resetDefaults({
    required String practitionerId,
    String? currentProfessionalId,
  }) async {
    final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
    if (normalizedPractitionerId.isEmpty) {
      return readAll(currentProfessionalId: currentProfessionalId);
    }

    await _remote.resetDefaults(normalizedPractitionerId);

    return replaceSchedule(
      practitionerId: normalizedPractitionerId,
      schedule: _cloneSchedule(defaultProfessionalSchedule),
      currentProfessionalId: currentProfessionalId,
    );
  }
}

String _normalizePractitionerId(String value) {
  return value.trim();
}

Map<String, List<DaySchedule>> _normalizeState(
  Map<String, List<DaySchedule>> input, {
  required String? currentProfessionalId,
}) {
  final result = <String, List<DaySchedule>>{};

  for (final entry in input.entries) {
    final normalizedPractitionerId = _normalizePractitionerId(entry.key);
    if (normalizedPractitionerId.isEmpty) continue;

    final normalizedSchedule = _sortAndNormalize(entry.value);
    if (normalizedSchedule.isEmpty) continue;

    result[normalizedPractitionerId] = normalizedSchedule;
  }

  result.putIfAbsent(
    defaultPractitionerId,
    () => _cloneSchedule(defaultProfessionalSchedule),
  );

  final normalizedCurrentProfessionalId =
      _normalizePractitionerId(currentProfessionalId ?? '');
  if (normalizedCurrentProfessionalId.isNotEmpty) {
    result.putIfAbsent(
      normalizedCurrentProfessionalId,
      () => _cloneSchedule(defaultProfessionalSchedule),
    );
  }

  return Map<String, List<DaySchedule>>.unmodifiable(result);
}

Map<String, List<DaySchedule>> _cloneState(
  Map<String, List<DaySchedule>> input,
) {
  return Map<String, List<DaySchedule>>.unmodifiable({
    for (final entry in input.entries) entry.key: _cloneSchedule(entry.value),
  });
}

List<DaySchedule> _cloneSchedule(List<DaySchedule> input) {
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

List<DaySchedule> _sortAndNormalize(List<DaySchedule> input) {
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

List<TimeSlot> replaceScheduleSlot(
  List<TimeSlot> slots,
  int? slotIndex,
  TimeSlot slot,
) {
  if (slotIndex == null || slotIndex < 0 || slotIndex >= slots.length) {
    return sortTimeSlots(slots);
  }

  final updated = [...slots];
  updated[slotIndex] = slot;
  return sortTimeSlots(updated);
}

List<TimeSlot> removeScheduleSlot(
  List<TimeSlot> slots,
  int? slotIndex,
) {
  if (slotIndex == null || slotIndex < 0 || slotIndex >= slots.length) {
    return sortTimeSlots(slots);
  }

  final updated = [...slots]..removeAt(slotIndex);
  return sortTimeSlots(updated);
}