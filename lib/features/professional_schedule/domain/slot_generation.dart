import 'professional_schedule.dart';

class SlotGenerationResult {
  const SlotGenerationResult({
    required this.isOpen,
    required this.slots,
  });

  final bool isOpen;

  /// Créneaux affichés côté patient au format : "08:00 - 08:30".
  ///
  /// Important :
  /// Les créneaux affichés côté patient doivent rester identiques
  /// aux créneaux définis côté professionnel.
  final List<String> slots;
}

SlotGenerationResult buildSlotsForDay({
  required DaySchedule schedule,
  required DateTime selectedDay,
  int appointmentDurationMinutes = 30,
  int minimumLeadTimeMinutes = 60,
  DateTime? now,
}) {
  if (!schedule.isOpen) {
    return const SlotGenerationResult(
      isOpen: false,
      slots: [],
    );
  }

  final safeLeadTime = minimumLeadTimeMinutes < 0 ? 0 : minimumLeadTimeMinutes;
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
    Duration(minutes: safeLeadTime),
  );

  final availableSlots = <String>[];

  for (final slot in sortTimeSlots(schedule.slots)) {
    final startMinutes = toMinutes(slot.start);
    final endMinutes = toMinutes(slot.end);

    if (startMinutes == null || endMinutes == null) {
      continue;
    }

    if (endMinutes <= startMinutes) {
      continue;
    }

    final slotStartDateTime = DateTime(
      normalizedSelectedDay.year,
      normalizedSelectedDay.month,
      normalizedSelectedDay.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );

    final isTooSoon = slotStartDateTime.isBefore(earliestAllowed);
    if (isTooSoon) {
      continue;
    }

    availableSlots.add(slot.label);
  }

  return SlotGenerationResult(
    isOpen: true,
    slots: List<String>.unmodifiable(availableSlots),
  );
}