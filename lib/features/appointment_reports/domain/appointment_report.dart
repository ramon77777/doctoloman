import 'package:flutter/foundation.dart';

@immutable
class AppointmentReport {
  AppointmentReport({
    required String id,
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String professionalId,
    required String professionalName,
    required DateTime appointmentDateTime,
    required String appointmentReason,
    required String summary,
    required String clinicalNotes,
    required String diagnosis,
    required String treatmentPlan,
    required String prescriptions,
    required String requestedExams,
    required String followUpInstructions,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : id = _clean(id),
        appointmentId = _clean(appointmentId),
        patientId = _clean(patientId),
        patientName = _clean(patientName),
        professionalId = _clean(professionalId),
        professionalName = _clean(professionalName),
        appointmentDateTime = appointmentDateTime,
        appointmentReason = _cleanMultiline(appointmentReason),
        summary = _cleanMultiline(summary),
        clinicalNotes = _cleanMultiline(clinicalNotes),
        diagnosis = _cleanMultiline(diagnosis),
        treatmentPlan = _cleanMultiline(treatmentPlan),
        prescriptions = _cleanMultiline(prescriptions),
        requestedExams = _cleanMultiline(requestedExams),
        followUpInstructions = _cleanMultiline(followUpInstructions),
        createdAt = createdAt,
        updatedAt = updatedAt;

  final String id;
  final String appointmentId;

  final String patientId;
  final String patientName;

  final String professionalId;
  final String professionalName;

  final DateTime appointmentDateTime;
  final String appointmentReason;

  final String summary;
  final String clinicalNotes;
  final String diagnosis;
  final String treatmentPlan;
  final String prescriptions;
  final String requestedExams;
  final String followUpInstructions;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSummary => summary.trim().isNotEmpty;
  bool get hasClinicalNotes => clinicalNotes.trim().isNotEmpty;
  bool get hasDiagnosis => diagnosis.trim().isNotEmpty;
  bool get hasTreatmentPlan => treatmentPlan.trim().isNotEmpty;
  bool get hasPrescriptions => prescriptions.trim().isNotEmpty;
  bool get hasRequestedExams => requestedExams.trim().isNotEmpty;
  bool get hasFollowUpInstructions => followUpInstructions.trim().isNotEmpty;

  AppointmentReport copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? patientName,
    String? professionalId,
    String? professionalName,
    DateTime? appointmentDateTime,
    String? appointmentReason,
    String? summary,
    String? clinicalNotes,
    String? diagnosis,
    String? treatmentPlan,
    String? prescriptions,
    String? requestedExams,
    String? followUpInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentReport(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      professionalId: professionalId ?? this.professionalId,
      professionalName: professionalName ?? this.professionalName,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      appointmentReason: appointmentReason ?? this.appointmentReason,
      summary: summary ?? this.summary,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      diagnosis: diagnosis ?? this.diagnosis,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      prescriptions: prescriptions ?? this.prescriptions,
      requestedExams: requestedExams ?? this.requestedExams,
      followUpInstructions:
          followUpInstructions ?? this.followUpInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'professionalId': professionalId,
      'professionalName': professionalName,
      'appointmentDateTime': appointmentDateTime.toIso8601String(),
      'appointmentReason': appointmentReason,
      'summary': summary,
      'clinicalNotes': clinicalNotes,
      'diagnosis': diagnosis,
      'treatmentPlan': treatmentPlan,
      'prescriptions': prescriptions,
      'requestedExams': requestedExams,
      'followUpInstructions': followUpInstructions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppointmentReport.fromMap(Map<String, dynamic> map) {
    return AppointmentReport(
      id: (map['id'] as String?) ?? '',
      appointmentId: (map['appointmentId'] as String?) ?? '',
      patientId: (map['patientId'] as String?) ?? '',
      patientName: (map['patientName'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      professionalName: (map['professionalName'] as String?) ?? '',
      appointmentDateTime:
          _parseDate(map['appointmentDateTime']) ?? DateTime.now(),
      appointmentReason: (map['appointmentReason'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      clinicalNotes: (map['clinicalNotes'] as String?) ?? '',
      diagnosis: (map['diagnosis'] as String?) ?? '',
      treatmentPlan: (map['treatmentPlan'] as String?) ?? '',
      prescriptions: (map['prescriptions'] as String?) ?? '',
      requestedExams: (map['requestedExams'] as String?) ?? '',
      followUpInstructions:
          (map['followUpInstructions'] as String?) ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _cleanMultiline(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  @override
  bool operator ==(Object other) {
    return other is AppointmentReport &&
        other.id == id &&
        other.appointmentId == appointmentId &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, appointmentId, updatedAt);
}