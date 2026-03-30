import 'package:flutter/foundation.dart';

@immutable
class DaySchedule {
  const DaySchedule({
    required this.weekday,
    required this.label,
    required this.isOpen,
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonStart,
    required this.afternoonEnd,
  });

  final int weekday; // 1=lundi ... 7=dimanche
  final String label;
  final bool isOpen;

  final String? morningStart;
  final String? morningEnd;
  final String? afternoonStart;
  final String? afternoonEnd;

  DaySchedule copyWith({
    int? weekday,
    String? label,
    bool? isOpen,
    String? morningStart,
    String? morningEnd,
    String? afternoonStart,
    String? afternoonEnd,
    bool clearMorning = false,
    bool clearAfternoon = false,
  }) {
    return DaySchedule(
      weekday: weekday ?? this.weekday,
      label: label ?? this.label,
      isOpen: isOpen ?? this.isOpen,
      morningStart: clearMorning ? null : (morningStart ?? this.morningStart),
      morningEnd: clearMorning ? null : (morningEnd ?? this.morningEnd),
      afternoonStart:
          clearAfternoon ? null : (afternoonStart ?? this.afternoonStart),
      afternoonEnd:
          clearAfternoon ? null : (afternoonEnd ?? this.afternoonEnd),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'label': label,
      'isOpen': isOpen,
      'morningStart': morningStart,
      'morningEnd': morningEnd,
      'afternoonStart': afternoonStart,
      'afternoonEnd': afternoonEnd,
    };
  }

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    return DaySchedule(
      weekday: _readInt(map, 'weekday', 1),
      label: _readString(map, 'label', 'Jour'),
      isOpen: _readBool(map, 'isOpen', false),
      morningStart: _readNullableString(map, 'morningStart'),
      morningEnd: _readNullableString(map, 'morningEnd'),
      afternoonStart: _readNullableString(map, 'afternoonStart'),
      afternoonEnd: _readNullableString(map, 'afternoonEnd'),
    );
  }

  String get morningLabel {
    if (morningStart == null || morningEnd == null) return 'Non défini';
    return '$morningStart - $morningEnd';
  }

  String get afternoonLabel {
    if (afternoonStart == null || afternoonEnd == null) return 'Non défini';
    return '$afternoonStart - $afternoonEnd';
  }

  String get summary {
    if (!isOpen) return 'Fermé';

    final parts = <String>[];
    if (morningStart != null && morningEnd != null) {
      parts.add('$morningStart - $morningEnd');
    }
    if (afternoonStart != null && afternoonEnd != null) {
      parts.add('$afternoonStart - $afternoonEnd');
    }

    if (parts.isEmpty) return 'Horaires non définis';
    return parts.join(' • ');
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

  static String? _readNullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}