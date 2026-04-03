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
  int minimumLeadTimeMinutes = 60,
  DateTime? now,
}) {
  if (!schedule.isOpen) {
    return const SlotGenerationResult(
      isOpen: false,
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

  final availableSlots = <String>[];

  for (final slot in schedule.slots) {
    final startMinutes = toMinutes(slot.start);
    final endMinutes = toMinutes(slot.end);

    if (startMinutes == null || endMinutes == null) {
      continue;
    }

    if (endMinutes <= startMinutes) {
      continue;
    }

    final slotStart = DateTime(
      normalizedSelectedDay.year,
      normalizedSelectedDay.month,
      normalizedSelectedDay.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );

    final isTooSoon = slotStart.isBefore(earliestAllowed);
    if (isTooSoon) {
      continue;
    }

    availableSlots.add('${slot.start} - ${slot.end}');
  }

  return SlotGenerationResult(
    isOpen: true,
    slots: List<String>.unmodifiable(availableSlots),
  );
}