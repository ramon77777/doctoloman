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
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: _readString(map, 'start', ''),
      end: _readString(map, 'end', ''),
    );
  }

  String get label => '$start - $end';

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
    return DaySchedule(
      weekday: weekday ?? this.weekday,
      label: label ?? this.label,
      isOpen: isOpen ?? this.isOpen,
      slots: clearSlots ? const <TimeSlot>[] : (slots ?? this.slots),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'label': label,
      'isOpen': isOpen,
      'slots': slots.map((slot) => slot.toMap()).toList(),
    };
  }

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    final rawSlots = map['slots'];
    final parsedSlots = <TimeSlot>[];

    if (rawSlots is List) {
      for (final entry in rawSlots) {
        if (entry is! Map) continue;
        try {
          parsedSlots.add(TimeSlot.fromMap(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // Ignore uniquement l'entrée invalide.
        }
      }
    }

    return DaySchedule(
      weekday: _readInt(map, 'weekday', 1),
      label: _readString(map, 'label', 'Jour'),
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
}

List<TimeSlot> sortTimeSlots(List<TimeSlot> input) {
  return List<TimeSlot>.unmodifiable(_sortSlots(input));
}

List<TimeSlot> _sortSlots(List<TimeSlot> input) {
  final sorted = [...input];
  sorted.sort((a, b) {
    final aStart = toMinutes(a.start) ?? 0;
    final bStart = toMinutes(b.start) ?? 0;
    if (aStart != bStart) return aStart.compareTo(bStart);

    final aEnd = toMinutes(a.end) ?? 0;
    final bEnd = toMinutes(b.end) ?? 0;
    return aEnd.compareTo(bEnd);
  });
  return sorted;
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