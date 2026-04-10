import 'package:flutter/foundation.dart';

@immutable
class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  TimeSlot copyWith({
    String? start,
    String? end,
  }) {
    return TimeSlot(
      start: _normalizeHour(start ?? this.start),
      end: _normalizeHour(end ?? this.end),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': _normalizeHour(start),
      'end': _normalizeHour(end),
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: _normalizeHour(_readString(map, 'start', '')),
      end: _normalizeHour(_readString(map, 'end', '')),
    );
  }

  String get label => '${_normalizeHour(start)} - ${_normalizeHour(end)}';

  static String _readString(
    Map<String, dynamic> map,
    String key,
    String fallback,
  ) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimeSlot &&
        _normalizeHour(other.start) == _normalizeHour(start) &&
        _normalizeHour(other.end) == _normalizeHour(end);
  }

  @override
  int get hashCode => Object.hash(
        _normalizeHour(start),
        _normalizeHour(end),
      );
}

@immutable
class DaySchedule {
  const DaySchedule({
    required this.weekday,
    required this.label,
    required this.isOpen,
    required this.slots,
  });

  final int weekday; // 1=lundi ... 7=dimanche
  final String label;
  final bool isOpen;
  final List<TimeSlot> slots;

  DaySchedule copyWith({
    int? weekday,
    String? label,
    bool? isOpen,
    List<TimeSlot>? slots,
    bool clearSlots = false,
  }) {
    final nextSlots = clearSlots
        ? const <TimeSlot>[]
        : (slots ?? this.slots);

    return DaySchedule(
      weekday: _normalizeWeekday(weekday ?? this.weekday),
      label: _normalizeLabel(label ?? this.label),
      isOpen: isOpen ?? this.isOpen,
      slots: List<TimeSlot>.unmodifiable(
        sortTimeSlots(nextSlots),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekday': _normalizeWeekday(weekday),
      'label': _normalizeLabel(label),
      'isOpen': isOpen,
      'slots': sortTimeSlots(slots).map((slot) => slot.toMap()).toList(),
    };
  }

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    final rawSlots = map['slots'];
    final parsedSlots = <TimeSlot>[];

    if (rawSlots is List) {
      for (final entry in rawSlots) {
        if (entry is! Map) continue;

        try {
          final slot = TimeSlot.fromMap(Map<String, dynamic>.from(entry));
          final startMinutes = toMinutes(slot.start);
          final endMinutes = toMinutes(slot.end);

          if (startMinutes == null || endMinutes == null) {
            continue;
          }

          if (startMinutes >= endMinutes) {
            continue;
          }

          parsedSlots.add(slot);
        } catch (_) {
          // Ignore uniquement l'entrée invalide.
        }
      }
    }

    return DaySchedule(
      weekday: _normalizeWeekday(_readInt(map, 'weekday', 1)),
      label: _normalizeLabel(_readString(map, 'label', 'Jour')),
      isOpen: _readBool(map, 'isOpen', false),
      slots: List<TimeSlot>.unmodifiable(_sortSlots(parsedSlots)),
    );
  }

  String get summary {
    if (!isOpen) return 'Fermé';
    if (slots.isEmpty) return 'Aucun créneau défini';
    return '${slots.length} créneau(x)';
  }

  static int _readInt(Map<String, dynamic> map, String key, int fallback) {
    final value = map[key];
    if (value is int) return value;
    return fallback;
  }

  static bool _readBool(Map<String, dynamic> map, String key, bool fallback) {
    final value = map[key];
    if (value is bool) return value;
    return fallback;
  }

  static String _readString(
    Map<String, dynamic> map,
    String key,
    String fallback,
  ) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static int _normalizeWeekday(int value) {
    if (value < 1) return 1;
    if (value > 7) return 7;
    return value;
  }

  static String _normalizeLabel(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? 'Jour' : normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DaySchedule &&
        other.weekday == weekday &&
        other.label == label &&
        other.isOpen == isOpen &&
        listEquals(other.slots, slots);
  }

  @override
  int get hashCode => Object.hash(
        weekday,
        label,
        isOpen,
        Object.hashAll(slots),
      );
}

List<TimeSlot> sortTimeSlots(List<TimeSlot> input) {
  return List<TimeSlot>.unmodifiable(_sortSlots(input));
}

List<TimeSlot> _sortSlots(List<TimeSlot> input) {
  final normalized = <TimeSlot>[];

  for (final slot in input) {
    final normalizedSlot = slot.copyWith();
    final startMinutes = toMinutes(normalizedSlot.start);
    final endMinutes = toMinutes(normalizedSlot.end);

    if (startMinutes == null || endMinutes == null) {
      continue;
    }

    if (startMinutes >= endMinutes) {
      continue;
    }

    normalized.add(normalizedSlot);
  }

  normalized.sort((a, b) {
    final aStart = toMinutes(a.start) ?? 0;
    final bStart = toMinutes(b.start) ?? 0;
    if (aStart != bStart) return aStart.compareTo(bStart);

    final aEnd = toMinutes(a.end) ?? 0;
    final bEnd = toMinutes(b.end) ?? 0;
    return aEnd.compareTo(bEnd);
  });

  final deduplicated = <TimeSlot>[];
  final seen = <String>{};

  for (final slot in normalized) {
    final key = '${slot.start}-${slot.end}';
    if (!seen.add(key)) continue;
    deduplicated.add(slot);
  }

  return deduplicated;
}

int? toMinutes(String hhmm) {
  final value = hhmm.trim();
  if (value.isEmpty) return null;

  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;

  return hh * 60 + mm;
}

String formatMinutes(int totalMinutes) {
  final hh = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final mm = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _normalizeHour(String value) {
  final trimmed = value.trim();
  final parts = trimmed.split(':');

  if (parts.length != 2) {
    return trimmed;
  }

  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) {
    return trimmed;
  }

  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
    return trimmed;
  }

  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}