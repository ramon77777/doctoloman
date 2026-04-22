import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../medical_records/data/in_memory_medical_records_repository.dart';
import '../../../medical_records/data/medical_records_local_storage.dart';
import '../../../medical_records/domain/medical_record.dart';
import '../../../medical_records/presentation/providers/medical_records_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../data/appointment_reports_local_storage.dart';
import '../../data/in_memory_appointment_reports_repository.dart';
import '../../domain/appointment_report.dart';
import '../../domain/appointment_reports_repository.dart';

final appointmentReportsLocalStorageProvider =
    Provider<AppointmentReportsLocalStorage>(
  (ref) => AppointmentReportsLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'appointmentReportsLocalStorageProvider',
);

final appointmentReportsRepositoryProvider =
    Provider<AppointmentReportsRepository>(
  (ref) => InMemoryAppointmentReportsRepository(
    ref.watch(appointmentReportsLocalStorageProvider),
  ),
  name: 'appointmentReportsRepositoryProvider',
);

final appointmentReportByAppointmentIdProvider =
    FutureProvider.family<AppointmentReport?, String>((ref, appointmentId) async {
  final normalizedId = appointmentId.trim();
  if (normalizedId.isEmpty) return null;

  final reportRepo = ref.watch(appointmentReportsRepositoryProvider);
  final appointment =
      await ref.watch(appointmentByIdProvider(normalizedId).future);

  if (appointment == null) {
    return null;
  }

  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;

  if (authUser == null) {
    return null;
  }

  if (authState.isProfessional) {
    final profile = ref.watch(professionalProfileProvider);

    if (!_belongsToProfessional(
      appointment: appointment,
      profile: profile,
      authUser: authUser,
    )) {
      return null;
    }
  } else if (authState.isPatient) {
    final authPatientKey = _normalizePatientStorageKey(authUser.phone);
    final appointmentPatientKey =
        _normalizePatientStorageKey(appointment.patientPhoneE164);

    if (authPatientKey.isEmpty || authPatientKey != appointmentPatientKey) {
      return null;
    }
  } else {
    return null;
  }

  return reportRepo.getByAppointmentId(normalizedId);
}, name: 'appointmentReportByAppointmentIdProvider');

final appointmentReportsControllerProvider =
    Provider<AppointmentReportsController>(
  (ref) {
    final reportsRepo = ref.watch(appointmentReportsRepositoryProvider);
    final medicalRecordsLocalStorage =
        ref.watch(medicalRecordsLocalStorageProvider);

    return AppointmentReportsController(
      ref: ref,
      reportsRepo: reportsRepo,
      medicalRecordsLocalStorage: medicalRecordsLocalStorage,
    );
  },
  name: 'appointmentReportsControllerProvider',
);

class AppointmentReportsController {
  AppointmentReportsController({
    required Ref ref,
    required AppointmentReportsRepository reportsRepo,
    required MedicalRecordsLocalStorage medicalRecordsLocalStorage,
  })  : _ref = ref,
        _reportsRepo = reportsRepo,
        _medicalRecordsLocalStorage = medicalRecordsLocalStorage;

  final Ref _ref;
  final AppointmentReportsRepository _reportsRepo;
  final MedicalRecordsLocalStorage _medicalRecordsLocalStorage;

  Future<void> save(AppointmentReport report) async {
    final securedAppointment = await _resolveAuthorizedCompletedAppointment(
      report.appointmentId,
    );

    if (securedAppointment == null) {
      throw StateError(
        'Enregistrement refusé : rendez-vous introuvable, non terminé, non confirmé ou non autorisé.',
      );
    }

    final existingReport = await _reportsRepo.getByAppointmentId(
      securedAppointment.id,
    );

    final securedReport = _buildSecuredReport(
      base: report,
      appointment: securedAppointment,
      existingReport: existingReport,
    );

    await _reportsRepo.save(securedReport);
    await _upsertLinkedMedicalRecord(securedReport);

    _ref.invalidate(
      appointmentReportByAppointmentIdProvider(securedReport.appointmentId),
    );

    _invalidateMedicalRecordViews(
      patientId: securedReport.patientId,
      appointmentId: securedReport.appointmentId,
    );
  }

  Future<void> deleteById({
    required String id,
    required String appointmentId,
  }) async {
    final securedAppointment = await _resolveAuthorizedCompletedAppointment(
      appointmentId,
    );

    if (securedAppointment == null) {
      throw StateError(
        'Suppression refusée : rendez-vous introuvable, non terminé, non confirmé ou non autorisé.',
      );
    }

    final existingReport = await _reportsRepo.getByAppointmentId(appointmentId);
    if (existingReport == null) {
      return;
    }

    final normalizedId = id.trim();
    if (normalizedId.isEmpty || existingReport.id != normalizedId) {
      throw StateError('Suppression refusée : identifiant bilan invalide.');
    }

    await _reportsRepo.deleteById(normalizedId);
    await _deleteLinkedMedicalRecord(existingReport);

    _ref.invalidate(
      appointmentReportByAppointmentIdProvider(appointmentId),
    );

    _invalidateMedicalRecordViews(
      patientId: existingReport.patientId,
      appointmentId: appointmentId,
    );
  }

  Future<Appointment?> _resolveAuthorizedCompletedAppointment(
    String appointmentId,
  ) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) return null;

    final authState = _ref.read(authControllerProvider);
    final authUser = authState.user;

    if (!authState.isAuthenticated ||
        !authState.isProfessional ||
        authUser == null) {
      return null;
    }

    final appointment = await _ref.read(
      appointmentByIdProvider(normalizedId).future,
    );

    if (appointment == null) {
      return null;
    }

    if (appointment.status != AppointmentStatus.confirmed) {
      return null;
    }

    // Défense en profondeur : impossible d'écrire le bilan avant l'heure.
    if (appointment.isUpcoming) {
      return null;
    }

    final profile = _ref.read(professionalProfileProvider);

    final allowed = _belongsToProfessional(
      appointment: appointment,
      profile: profile,
      authUser: authUser,
    );

    if (!allowed) {
      return null;
    }

    return appointment;
  }

  AppointmentReport _buildSecuredReport({
    required AppointmentReport base,
    required Appointment appointment,
    required AppointmentReport? existingReport,
  }) {
    final now = DateTime.now();
    final normalizedPatientId =
        _normalizePatientStorageKey(appointment.patientPhoneE164);

    final existingId = existingReport?.id.trim() ?? '';
    final baseId = base.id.trim();

    return AppointmentReport(
      id: existingId.isNotEmpty
          ? existingId
          : (baseId.isNotEmpty ? baseId : 'ar_${now.microsecondsSinceEpoch}'),
      appointmentId: appointment.id,
      patientId: normalizedPatientId,
      patientName: appointment.patientFullName,
      professionalId: appointment.practitionerId,
      professionalName: appointment.practitionerName,
      appointmentDateTime: appointment.scheduledAt,
      appointmentReason: appointment.reason,
      summary: base.summary,
      clinicalNotes: base.clinicalNotes,
      diagnosis: base.diagnosis,
      treatmentPlan: base.treatmentPlan,
      prescriptions: base.prescriptions,
      requestedExams: base.requestedExams,
      followUpInstructions: base.followUpInstructions,
      createdAt: existingReport?.createdAt ?? base.createdAt,
      updatedAt: now,
    );
  }

  Future<void> _upsertLinkedMedicalRecord(AppointmentReport report) async {
    final patientKey = _normalizePatientStorageKey(report.patientId);
    if (patientKey.isEmpty) return;

    final medicalRecordsRepo = InMemoryMedicalRecordsRepository(
      _medicalRecordsLocalStorage,
      patientKey: patientKey,
    );

    final linkedRecordId = _linkedMedicalRecordId(report.appointmentId);
    final existingRecord = await medicalRecordsRepo.getById(linkedRecordId);

    final nextRecord = MedicalRecord(
      id: linkedRecordId,
      patientId: patientKey,
      title: _buildMedicalRecordTitle(report),
      category: MedicalRecordCategory.report,
      recordDate: DateTime(
        report.appointmentDateTime.year,
        report.appointmentDateTime.month,
        report.appointmentDateTime.day,
      ),
      createdAt: existingRecord?.createdAt ?? report.createdAt,
      patientName: report.patientName,
      sourceLabel: report.professionalName,
      summary: _buildMedicalRecordSummary(report),
      isSensitive: true,
      description: _buildMedicalRecordDescription(report),
    );

    if (existingRecord == null) {
      await medicalRecordsRepo.create(nextRecord);
    } else {
      await medicalRecordsRepo.update(nextRecord);
    }
  }

  Future<void> _deleteLinkedMedicalRecord(AppointmentReport report) async {
    final patientKey = _normalizePatientStorageKey(report.patientId);
    if (patientKey.isEmpty) return;

    final medicalRecordsRepo = InMemoryMedicalRecordsRepository(
      _medicalRecordsLocalStorage,
      patientKey: patientKey,
    );

    await medicalRecordsRepo.deleteById(
      _linkedMedicalRecordId(report.appointmentId),
    );
  }

  void _invalidateMedicalRecordViews({
    required String patientId,
    required String appointmentId,
  }) {
    final normalizedPatientId = _normalizePatientStorageKey(patientId);
    if (normalizedPatientId.isEmpty) return;

    _ref.invalidate(
      medicalRecordsByPatientIdProvider(normalizedPatientId),
    );

    _ref.invalidate(
      medicalRecordByIdProvider(_linkedMedicalRecordId(appointmentId)),
    );

    final authUser = _ref.read(authControllerProvider).user;
    final authPatientKey = _normalizePatientStorageKey(authUser?.phone ?? '');

    if (authPatientKey == normalizedPatientId) {
      _ref.invalidate(medicalRecordsListProvider);
      _ref.invalidate(filteredMedicalRecordsProvider);
    }
  }

  String _linkedMedicalRecordId(String appointmentId) {
    return 'report_${appointmentId.trim()}';
  }

  String _buildMedicalRecordTitle(AppointmentReport report) {
    return 'Compte rendu de consultation';
  }

  String _buildMedicalRecordSummary(AppointmentReport report) {
    final parts = <String>[
      if (report.summary.trim().isNotEmpty) report.summary.trim(),
      if (report.diagnosis.trim().isNotEmpty)
        'Diagnostic : ${report.diagnosis.trim()}',
      if (report.treatmentPlan.trim().isNotEmpty)
        'Traitement : ${report.treatmentPlan.trim()}',
    ];

    if (parts.isEmpty) {
      return 'Compte rendu médical disponible.';
    }

    return parts.join('\n');
  }

  String _buildMedicalRecordDescription(AppointmentReport report) {
    final sections = <String>[
      if (report.appointmentReason.trim().isNotEmpty)
        'Motif de consultation:\n${report.appointmentReason.trim()}',
      if (report.summary.trim().isNotEmpty)
        'Résumé:\n${report.summary.trim()}',
      if (report.clinicalNotes.trim().isNotEmpty)
        'Notes cliniques:\n${report.clinicalNotes.trim()}',
      if (report.diagnosis.trim().isNotEmpty)
        'Diagnostic:\n${report.diagnosis.trim()}',
      if (report.treatmentPlan.trim().isNotEmpty)
        'Traitement:\n${report.treatmentPlan.trim()}',
      if (report.prescriptions.trim().isNotEmpty)
        'Prescription:\n${report.prescriptions.trim()}',
      if (report.requestedExams.trim().isNotEmpty)
        'Examens demandés:\n${report.requestedExams.trim()}',
      if (report.followUpInstructions.trim().isNotEmpty)
        'Suivi:\n${report.followUpInstructions.trim()}',
    ];

    if (sections.isEmpty) {
      return 'Aucun détail renseigné.';
    }

    return sections.join('\n\n');
  }
}

bool _belongsToProfessional({
  required Appointment appointment,
  required ProfessionalProfile profile,
  required AppUser? authUser,
}) {
  final appointmentPractitionerId = appointment.practitionerId.trim();
  final appointmentPractitionerName =
      StringNormalizers.normalizeLoose(appointment.practitionerName);

  final profileId = profile.id.trim();
  final profileName = StringNormalizers.normalizeLoose(profile.displayName);

  final authId = authUser?.id.trim() ?? '';
  final authName = StringNormalizers.normalizeLoose(authUser?.name ?? '');

  final byProfileId =
      profileId.isNotEmpty && appointmentPractitionerId == profileId;
  final byProfileName =
      profileName.isNotEmpty && appointmentPractitionerName == profileName;
  final byAuthId = authId.isNotEmpty && appointmentPractitionerId == authId;
  final byAuthName =
      authName.isNotEmpty && appointmentPractitionerName == authName;

  return byProfileId || byProfileName || byAuthId || byAuthName;
}

String _normalizePatientStorageKey(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}