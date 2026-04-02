import 'professional_schedule.dart';

class SlotGenerationResult {
  const SlotGenerationResult({
    required this.isOpen,
    required this.slots,
  });

  final bool isOpen;
  final List<String> slots;
}

SlotGenerationResult buildSlotsForDay({
  required DaySchedule schedule,
  required DateTime selectedDay,
  int intervalMinutes = 30,
  int consultationDurationMinutes = 30,
  int minimumLeadTimeMinutes = 60,
  DateTime? now,
}) {
  if (!schedule.isOpen) {
    return const SlotGenerationResult(
      isOpen: false,
      slots: [],
    );
  }

  if (intervalMinutes <= 0 || consultationDurationMinutes <= 0) {
    return const SlotGenerationResult(
      isOpen: true,
      slots: [],
    );
  }

  final effectiveNow = now ?? DateTime.now();

  final normalizedSelectedDay = DateTime(
    selectedDay.year,
    selectedDay.month,
    selectedDay.day,
  );

  final normalizedToday = DateTime(
    effectiveNow.year,
    effectiveNow.month,
    effectiveNow.day,
  );

  if (normalizedSelectedDay.isBefore(normalizedToday)) {
    return const SlotGenerationResult(
      isOpen: true,
      slots: [],
    );
  }

  final earliestAllowed = effectiveNow.add(
    Duration(minutes: minimumLeadTimeMinutes),
  );

  final slots = <String>[];

  void addRange(String? start, String? end) {
    if (start == null || end == null) return;

    final startMinutes = _toMinutes(start);
    final endMinutes = _toMinutes(end);

    if (startMinutes == null || endMinutes == null) return;
    if (endMinutes <= startMinutes) return;

    var cursor = startMinutes;

    while (cursor + consultationDurationMinutes <= endMinutes) {
      final slotStart = DateTime(
        normalizedSelectedDay.year,
        normalizedSelectedDay.month,
        normalizedSelectedDay.day,
        cursor ~/ 60,
        cursor % 60,
      );

      final slotEndMinutes = cursor + consultationDurationMinutes;

      final isTooSoon = slotStart.isBefore(earliestAllowed);

      if (!isTooSoon) {
        slots.add(
          '${_formatMinutes(cursor)} - ${_formatMinutes(slotEndMinutes)}',
        );
      }

      cursor += intervalMinutes;
    }
  }

  addRange(schedule.morningStart, schedule.morningEnd);
  addRange(schedule.afternoonStart, schedule.afternoonEnd);

  return SlotGenerationResult(
    isOpen: true,
    slots: List<String>.unmodifiable(slots),
  );
}

int? _toMinutes(String hhmm) {
  final value = hhmm.trim();
  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;

  return hh * 60 + mm;
}

String _formatMinutes(int totalMinutes) {
  final hh = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final mm = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}