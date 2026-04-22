import 'package:flutter/foundation.dart';

enum MedicalRecordCategory {
  prescription,
  labResult,
  imaging,
  certificate,
  report,
  other,
}

enum MedicalRecordOrigin {
  manualPatientEntry,
  professionalAppointmentReport,
  professionalManualEntry,
  imported,
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
    DateTime? updatedAt,
    MedicalRecordOrigin? origin,
    String? linkedAppointmentId,
    String? authorProfessionalId,
    String? authorProfessionalName,
  })  : id = _cleanText(id),
        patientId = _cleanText(patientId),
        title = _cleanText(title),
        recordDate = _normalizeDate(recordDate),
        createdAt = _normalizeDateTime(createdAt),
        updatedAt = _normalizeDateTime(updatedAt ?? createdAt),
        patientName = _cleanText(patientName),
        sourceLabel = _cleanText(sourceLabel),
        summary = _cleanMultilineText(summary),
        description = _cleanNullableMultilineText(description),
        origin = origin ?? _inferOrigin(
          category: category,
          linkedAppointmentId: linkedAppointmentId,
        ),
        linkedAppointmentId = _cleanNullableText(linkedAppointmentId),
        authorProfessionalId = _cleanNullableText(authorProfessionalId),
        authorProfessionalName = _cleanNullableText(authorProfessionalName);

  final String id;
  final String patientId;
  final String title;
  final MedicalRecordCategory category;
  final DateTime recordDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String patientName;
  final String sourceLabel;
  final String summary;
  final bool isSensitive;
  final String? description;

  final MedicalRecordOrigin origin;
  final String? linkedAppointmentId;
  final String? authorProfessionalId;
  final String? authorProfessionalName;

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

  bool get isLinkedToAppointment {
    final linkedId = linkedAppointmentId?.trim();
    return linkedId != null && linkedId.isNotEmpty;
  }

  bool get hasAuthorProfessional {
    final id = authorProfessionalId?.trim();
    final name = authorProfessionalName?.trim();
    return (id != null && id.isNotEmpty) || (name != null && name.isNotEmpty);
  }

  bool get isAppointmentReportOrigin =>
      origin == MedicalRecordOrigin.professionalAppointmentReport;

  MedicalRecord copyWith({
    String? id,
    String? patientId,
    String? title,
    MedicalRecordCategory? category,
    DateTime? recordDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
    String? sourceLabel,
    String? summary,
    bool? isSensitive,
    String? description,
    MedicalRecordOrigin? origin,
    String? linkedAppointmentId,
    String? authorProfessionalId,
    String? authorProfessionalName,
    bool clearDescription = false,
    bool clearLinkedAppointmentId = false,
    bool clearAuthorProfessionalId = false,
    bool clearAuthorProfessionalName = false,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      category: category ?? this.category,
      recordDate: recordDate ?? this.recordDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      patientName: patientName ?? this.patientName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      summary: summary ?? this.summary,
      isSensitive: isSensitive ?? this.isSensitive,
      description: clearDescription ? null : (description ?? this.description),
      origin: origin ?? this.origin,
      linkedAppointmentId: clearLinkedAppointmentId
          ? null
          : (linkedAppointmentId ?? this.linkedAppointmentId),
      authorProfessionalId: clearAuthorProfessionalId
          ? null
          : (authorProfessionalId ?? this.authorProfessionalId),
      authorProfessionalName: clearAuthorProfessionalName
          ? null
          : (authorProfessionalName ?? this.authorProfessionalName),
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
      'updatedAt': updatedAt.toIso8601String(),
      'patientName': patientName,
      'sourceLabel': sourceLabel,
      'summary': summary,
      'isSensitive': isSensitive,
      'description': description,
      'origin': origin.name,
      'linkedAppointmentId': linkedAppointmentId,
      'authorProfessionalId': authorProfessionalId,
      'authorProfessionalName': authorProfessionalName,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    final category = _categoryFromString(map['category'] as String?);

    final linkedAppointmentId =
        _cleanNullableText(map['linkedAppointmentId'] as String?);

    return MedicalRecord(
      id: (map['id'] as String?) ?? '',
      patientId: (map['patientId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      category: category,
      recordDate: _parseDateOrNow(map['recordDate']),
      createdAt: _parseDateOrNow(map['createdAt']),
      updatedAt: _parseNullableDate(map['updatedAt']),
      patientName: (map['patientName'] as String?) ?? '',
      sourceLabel: (map['sourceLabel'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      isSensitive: (map['isSensitive'] as bool?) ?? true,
      description: map['description'] as String?,
      origin: _originFromString(
        map['origin'] as String?,
        fallbackCategory: category,
        fallbackLinkedAppointmentId: linkedAppointmentId,
      ),
      linkedAppointmentId: linkedAppointmentId,
      authorProfessionalId: map['authorProfessionalId'] as String?,
      authorProfessionalName: map['authorProfessionalName'] as String?,
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

  static MedicalRecordOrigin _originFromString(
    String? raw, {
    required MedicalRecordCategory fallbackCategory,
    required String? fallbackLinkedAppointmentId,
  }) {
    switch (raw) {
      case 'manualPatientEntry':
        return MedicalRecordOrigin.manualPatientEntry;
      case 'professionalAppointmentReport':
        return MedicalRecordOrigin.professionalAppointmentReport;
      case 'professionalManualEntry':
        return MedicalRecordOrigin.professionalManualEntry;
      case 'imported':
        return MedicalRecordOrigin.imported;
      default:
        return _inferOrigin(
          category: fallbackCategory,
          linkedAppointmentId: fallbackLinkedAppointmentId,
        );
    }
  }

  static MedicalRecordOrigin _inferOrigin({
    required MedicalRecordCategory category,
    required String? linkedAppointmentId,
  }) {
    final normalizedLinkedId = _cleanNullableText(linkedAppointmentId);

    if (category == MedicalRecordCategory.report &&
        normalizedLinkedId != null &&
        normalizedLinkedId.isNotEmpty) {
      return MedicalRecordOrigin.professionalAppointmentReport;
    }

    return MedicalRecordOrigin.manualPatientEntry;
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

  static DateTime? _parseNullableDate(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _normalizeDateTime(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: value.isUtc,
    );
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _cleanNullableText(String? value) {
    if (value == null) return null;

    final cleaned = _cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
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
        other.updatedAt == updatedAt &&
        other.patientName == patientName &&
        other.sourceLabel == sourceLabel &&
        other.summary == summary &&
        other.isSensitive == isSensitive &&
        other.description == description &&
        other.origin == origin &&
        other.linkedAppointmentId == linkedAppointmentId &&
        other.authorProfessionalId == authorProfessionalId &&
        other.authorProfessionalName == authorProfessionalName;
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
      updatedAt,
      patientName,
      sourceLabel,
      summary,
      isSensitive,
      description,
      origin,
      linkedAppointmentId,
      authorProfessionalId,
      authorProfessionalName,
    );
  }

  @override
  String toString() {
    return 'MedicalRecord('
        'id: $id, '
        'patientId: $patientId, '
        'title: $title, '
        'category: $category, '
        'origin: $origin, '
        'linkedAppointmentId: $linkedAppointmentId'
        ')';
  }
}