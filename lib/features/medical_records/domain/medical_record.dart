import 'package:flutter/foundation.dart';

enum MedicalRecordCategory {
  prescription,
  labResult,
  imaging,
  certificate,
  report,
  other,
}

@immutable
class MedicalRecord {
  MedicalRecord({
    required String id,
    required String patientId,
    required String title,
    required this.category,
    required DateTime recordDate,
    required DateTime createdAt,
    required String patientName,
    required String sourceLabel,
    required String summary,
    required this.isSensitive,
    String? description,
  })  : id = _cleanText(id),
        patientId = _cleanText(patientId),
        title = _cleanText(title),
        recordDate = _normalizeDate(recordDate),
        createdAt = createdAt,
        patientName = _cleanText(patientName),
        sourceLabel = _cleanText(sourceLabel),
        summary = _cleanMultilineText(summary),
        description = _cleanNullableMultilineText(description);

  final String id;
  final String patientId;
  final String title;
  final MedicalRecordCategory category;
  final DateTime recordDate;
  final DateTime createdAt;

  final String patientName;
  final String sourceLabel;
  final String summary;
  final bool isSensitive;

  /// Champ enrichi pour la suite, sans casser l’existant.
  final String? description;

  bool get hasDescription {
    final desc = description?.trim();
    return desc != null && desc.isNotEmpty;
  }

  String get effectiveDescription {
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      return desc;
    }
    return summary.trim();
  }

  MedicalRecord copyWith({
    String? id,
    String? patientId,
    String? title,
    MedicalRecordCategory? category,
    DateTime? recordDate,
    DateTime? createdAt,
    String? patientName,
    String? sourceLabel,
    String? summary,
    bool? isSensitive,
    String? description,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      category: category ?? this.category,
      recordDate: recordDate ?? this.recordDate,
      createdAt: createdAt ?? this.createdAt,
      patientName: patientName ?? this.patientName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      summary: summary ?? this.summary,
      isSensitive: isSensitive ?? this.isSensitive,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'title': title,
      'category': category.name,
      'recordDate': recordDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'patientName': patientName,
      'sourceLabel': sourceLabel,
      'summary': summary,
      'isSensitive': isSensitive,
      'description': description,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    return MedicalRecord(
      id: (map['id'] as String?) ?? '',
      patientId: (map['patientId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      category: _categoryFromString(map['category'] as String?),
      recordDate: _parseDateOrNow(map['recordDate']),
      createdAt: _parseDateOrNow(map['createdAt']),
      patientName: (map['patientName'] as String?) ?? '',
      sourceLabel: (map['sourceLabel'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      isSensitive: (map['isSensitive'] as bool?) ?? true,
      description: map['description'] as String?,
    );
  }

  static MedicalRecordCategory _categoryFromString(String? raw) {
    switch (raw) {
      case 'prescription':
        return MedicalRecordCategory.prescription;
      case 'labResult':
        return MedicalRecordCategory.labResult;
      case 'imaging':
        return MedicalRecordCategory.imaging;
      case 'certificate':
        return MedicalRecordCategory.certificate;
      case 'report':
        return MedicalRecordCategory.report;
      default:
        return MedicalRecordCategory.other;
    }
  }

  static DateTime _parseDateOrNow(Object? raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.now();
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _cleanMultilineText(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String? _cleanNullableMultilineText(String? value) {
    if (value == null) return null;

    final cleaned = _cleanMultilineText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MedicalRecord &&
        other.id == id &&
        other.patientId == patientId &&
        other.title == title &&
        other.category == category &&
        other.recordDate == recordDate &&
        other.createdAt == createdAt &&
        other.patientName == patientName &&
        other.sourceLabel == sourceLabel &&
        other.summary == summary &&
        other.isSensitive == isSensitive &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      patientId,
      title,
      category,
      recordDate,
      createdAt,
      patientName,
      sourceLabel,
      summary,
      isSensitive,
      description,
    );
  }

  @override
  String toString() {
    return 'MedicalRecord('
        'id: $id, '
        'patientId: $patientId, '
        'title: $title, '
        'category: $category'
        ')';
  }
}