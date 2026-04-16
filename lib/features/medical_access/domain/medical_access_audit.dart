import 'package:flutter/foundation.dart';

enum MedicalAccessAuditAction {
  openPatientMedicalRecords,
  openMedicalRecord,
}

@immutable
class MedicalAccessAudit {
  MedicalAccessAudit({
    required String id,
    required this.action,
    required String patientId,
    required String patientName,
    required String professionalId,
    required String professionalName,
    required DateTime createdAt,
    String? medicalAccessId,
    String? medicalRecordId,
    String? medicalRecordTitle,
  })  : id = _clean(id),
        patientId = _clean(patientId),
        patientName = _clean(patientName),
        professionalId = _clean(professionalId),
        professionalName = _clean(professionalName),
        medicalAccessId = _cleanNullable(medicalAccessId),
        medicalRecordId = _cleanNullable(medicalRecordId),
        medicalRecordTitle = _cleanNullable(medicalRecordTitle),
        createdAt = createdAt;

  final String id;
  final MedicalAccessAuditAction action;

  final String patientId;
  final String patientName;

  final String professionalId;
  final String professionalName;

  final DateTime createdAt;

  final String? medicalAccessId;
  final String? medicalRecordId;
  final String? medicalRecordTitle;

  MedicalAccessAudit copyWith({
    String? id,
    MedicalAccessAuditAction? action,
    String? patientId,
    String? patientName,
    String? professionalId,
    String? professionalName,
    DateTime? createdAt,
    String? medicalAccessId,
    String? medicalRecordId,
    String? medicalRecordTitle,
  }) {
    return MedicalAccessAudit(
      id: id ?? this.id,
      action: action ?? this.action,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      professionalId: professionalId ?? this.professionalId,
      professionalName: professionalName ?? this.professionalName,
      createdAt: createdAt ?? this.createdAt,
      medicalAccessId: medicalAccessId ?? this.medicalAccessId,
      medicalRecordId: medicalRecordId ?? this.medicalRecordId,
      medicalRecordTitle: medicalRecordTitle ?? this.medicalRecordTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action.name,
      'patientId': patientId,
      'patientName': patientName,
      'professionalId': professionalId,
      'professionalName': professionalName,
      'createdAt': createdAt.toIso8601String(),
      'medicalAccessId': medicalAccessId,
      'medicalRecordId': medicalRecordId,
      'medicalRecordTitle': medicalRecordTitle,
    };
  }

  factory MedicalAccessAudit.fromMap(Map<String, dynamic> map) {
    return MedicalAccessAudit(
      id: (map['id'] as String?) ?? '',
      action: _actionFromString(map['action'] as String?),
      patientId: (map['patientId'] as String?) ?? '',
      patientName: (map['patientName'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      professionalName: (map['professionalName'] as String?) ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      medicalAccessId: map['medicalAccessId'] as String?,
      medicalRecordId: map['medicalRecordId'] as String?,
      medicalRecordTitle: map['medicalRecordTitle'] as String?,
    );
  }

  static MedicalAccessAuditAction _actionFromString(String? raw) {
    switch (raw) {
      case 'openMedicalRecord':
        return MedicalAccessAuditAction.openMedicalRecord;
      case 'openPatientMedicalRecords':
      default:
        return MedicalAccessAuditAction.openPatientMedicalRecords;
    }
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _cleanNullable(String? value) {
    if (value == null) return null;
    final cleaned = _clean(value);
    return cleaned.isEmpty ? null : cleaned;
  }
}