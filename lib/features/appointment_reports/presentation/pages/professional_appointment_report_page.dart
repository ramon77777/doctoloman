import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../domain/appointment_report.dart';
import '../providers/appointment_reports_providers.dart';

class ProfessionalAppointmentReportPage extends ConsumerStatefulWidget {
  const ProfessionalAppointmentReportPage({
    super.key,
    required this.appointmentId,
  });

  final String appointmentId;

  @override
  ConsumerState<ProfessionalAppointmentReportPage> createState() =>
      _ProfessionalAppointmentReportPageState();
}

class _ProfessionalAppointmentReportPageState
    extends ConsumerState<ProfessionalAppointmentReportPage> {
  final _formKey = GlobalKey<FormState>();

  final _summaryCtrl = TextEditingController();
  final _clinicalNotesCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentPlanCtrl = TextEditingController();
  final _prescriptionsCtrl = TextEditingController();
  final _requestedExamsCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _clinicalNotesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _treatmentPlanCtrl.dispose();
    _prescriptionsCtrl.dispose();
    _requestedExamsCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  void _hydrate(AppointmentReport? report) {
    if (_initialized) return;

    if (report != null) {
      _summaryCtrl.text = report.summary;
      _clinicalNotesCtrl.text = report.clinicalNotes;
      _diagnosisCtrl.text = report.diagnosis;
      _treatmentPlanCtrl.text = report.treatmentPlan;
      _prescriptionsCtrl.text = report.prescriptions;
      _requestedExamsCtrl.text = report.requestedExams;
      _followUpCtrl.text = report.followUpInstructions;
    }

    _initialized = true;
  }

  String _cleanMultiline(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String? _requiredValidator(String? value, String label) {
    if (_cleanMultiline(value ?? '').isEmpty) {
      return '$label requis';
    }
    return null;
  }

  String _normalizePatientId(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  void _openPatientMedicalRecord(Appointment appointment) {
    final patientId = _normalizePatientId(appointment.patientPhoneE164);
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d’ouvrir le dossier patient : identifiant patient invalide.',
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.professionalPatientMedicalRecords,
      arguments: ProfessionalPatientMedicalRecordsArgs(
        patientId: patientId,
        patientName: appointment.patientFullName,
      ),
    );
  }

  Future<void> _save({
    required Appointment appointment,
    required AppointmentReport? existingReport,
  }) async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) return;

    if (appointment.status != AppointmentStatus.confirmed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Le bilan ne peut être enregistré que pour un rendez-vous confirmé.',
            ),
          ),
        );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final now = DateTime.now();

    final report = AppointmentReport(
      id: existingReport?.id ?? 'ar_${now.microsecondsSinceEpoch}',
      appointmentId: appointment.id,
      patientId: appointment.patientPhoneE164,
      patientName: appointment.patientFullName,
      professionalId: appointment.practitionerId,
      professionalName: appointment.practitionerName,
      appointmentDateTime: appointment.scheduledAt,
      appointmentReason: appointment.reason,
      summary: _cleanMultiline(_summaryCtrl.text),
      clinicalNotes: _cleanMultiline(_clinicalNotesCtrl.text),
      diagnosis: _cleanMultiline(_diagnosisCtrl.text),
      treatmentPlan: _cleanMultiline(_treatmentPlanCtrl.text),
      prescriptions: _cleanMultiline(_prescriptionsCtrl.text),
      requestedExams: _cleanMultiline(_requestedExamsCtrl.text),
      followUpInstructions: _cleanMultiline(_followUpCtrl.text),
      createdAt: existingReport?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(appointmentReportsControllerProvider).save(report);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              existingReport == null
                  ? 'Bilan enregistré et ajouté au dossier médical du patient.'
                  : 'Bilan mis à jour dans le dossier médical du patient.',
            ),
          ),
        );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible d’enregistrer le bilan.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedAppointmentId = widget.appointmentId.trim();

    if (normalizedAppointmentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bilan du rendez-vous'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun identifiant rendez-vous valide n’a été fourni.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authControllerProvider);
    final authUser = authState.user;
    final profile = ref.watch(professionalProfileProvider);

    final appointmentAsync = ref.watch(
      appointmentByIdProvider(normalizedAppointmentId),
    );
    final reportAsync = ref.watch(
      appointmentReportByAppointmentIdProvider(normalizedAppointmentId),
    );

    if (!authState.isAuthenticated || !authState.isProfessional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bilan du rendez-vous'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté avec un compte professionnel pour accéder à cette page.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan du rendez-vous'),
      ),
      body: SafeArea(
        child: appointmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur : $error')),
          data: (appointment) {
            if (appointment == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Rendez-vous introuvable.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!_belongsToProfessional(
              appointment: appointment,
              profile: profile,
              authUser: authUser,
            )) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Accès non autorisé : ce rendez-vous ne correspond pas au professionnel actif.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (appointment.status != AppointmentStatus.confirmed) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ContextCard(
                    appointment: appointment,
                    hasExistingReport: false,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Le bilan n’est accessible qu’après confirmation du rendez-vous.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (existingReport) {
                _hydrate(existingReport);

                return Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ContextCard(
                        appointment: appointment,
                        hasExistingReport: existingReport != null,
                      ),
                      const SizedBox(height: 14),
                      _PatientRecordLinkCard(
                        patientName: appointment.patientFullName,
                        onOpen: () => _openPatientMedicalRecord(appointment),
                      ),
                      const SizedBox(height: 16),
                      _MultilineField(
                        controller: _summaryCtrl,
                        label: 'Résumé de consultation',
                        hintText: 'Résumé synthétique du rendez-vous',
                        validator: (value) =>
                            _requiredValidator(value, 'Résumé'),
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _clinicalNotesCtrl,
                        label: 'Observations cliniques',
                        hintText: 'Constats, examen clinique, éléments utiles',
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _diagnosisCtrl,
                        label: 'Diagnostic / impression clinique',
                        hintText: 'Diagnostic retenu ou hypothèse clinique',
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _treatmentPlanCtrl,
                        label: 'Conduite à tenir',
                        hintText: 'Plan thérapeutique ou recommandations',
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _prescriptionsCtrl,
                        label: 'Prescription',
                        hintText: 'Traitements prescrits si applicable',
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _requestedExamsCtrl,
                        label: 'Examens demandés',
                        hintText: 'Bilans ou examens complémentaires',
                      ),
                      const SizedBox(height: 12),
                      _MultilineField(
                        controller: _followUpCtrl,
                        label: 'Suivi conseillé',
                        hintText:
                            'Contrôle, suivi, prochain rendez-vous conseillé',
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _save(
                                    appointment: appointment,
                                    existingReport: existingReport,
                                  ),
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? 'Enregistrement...'
                                : existingReport == null
                                    ? 'Enregistrer le bilan'
                                    : 'Mettre à jour le bilan',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openPatientMedicalRecord(appointment),
                          icon: const Icon(Icons.folder_shared_outlined),
                          label: const Text('Ouvrir le dossier du patient'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.appointment,
    required this.hasExistingReport,
  });

  final Appointment appointment;
  final bool hasExistingReport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasExistingReport ? 'Bilan existant' : 'Nouveau bilan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('Patient : ${appointment.patientFullName}'),
            const SizedBox(height: 4),
            Text('Motif : ${appointment.reason}'),
            const SizedBox(height: 4),
            Text(
              'Date : ${appointment.day.day}/${appointment.day.month}/${appointment.day.year} à ${appointment.slot}',
            ),
            const SizedBox(height: 10),
            Text(
              'Ce bilan est rattaché à ce rendez-vous et alimente le dossier médical du patient dans cette version MVP.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientRecordLinkCard extends StatelessWidget {
  const _PatientRecordLinkCard({
    required this.patientName,
    required this.onOpen,
  });

  final String patientName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.folder_shared_outlined, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dossier du patient',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vous pouvez consulter le dossier médical autorisé de $patientName en lecture seule.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Ouvrir le dossier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        alignLabelWithHint: true,
      ),
      validator: validator,
    );
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