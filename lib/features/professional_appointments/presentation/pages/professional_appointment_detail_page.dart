import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/ui/info_widgets.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../appointment_reports/presentation/providers/appointment_reports_providers.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/helpers/appointment_ui_helpers.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../appointments/presentation/widgets/appointment_badges.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../../teleconsultation/domain/teleconsultation_session.dart';
import '../../../teleconsultation/presentation/providers/teleconsultation_providers.dart';

class ProfessionalAppointmentDetailPage extends ConsumerWidget {
  const ProfessionalAppointmentDetailPage({
    super.key,
    required this.appointmentId,
  });

  final String appointmentId;

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref, {
    required Appointment appointment,
    required AppointmentStatus newStatus,
    required String successMessage,
  }) async {
    await ref.read(appointmentsControllerProvider).updateStatus(
          id: appointment.id,
          status: newStatus,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
  }

  Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref, {
    required Appointment appointment,
    required AppointmentStatus newStatus,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Retour'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    await _updateStatus(
      context,
      ref,
      appointment: appointment,
      newStatus: newStatus,
      successMessage: successMessage,
    );
  }

  bool _canWriteReport(Appointment appointment) {
    return appointment.status == AppointmentStatus.completed;
  }

  bool _canCreateTeleconsultation(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed;
  }

  String _reportLockedMessage(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'Le bilan sera accessible après confirmation puis réalisation du rendez-vous.';
      case AppointmentStatus.confirmed:
        if (appointment.isUpcoming) {
          return 'Le bilan ne peut être rédigé qu’après la tenue effective du rendez-vous.';
        }
        return 'Marquez d’abord ce rendez-vous comme réalisé pour rédiger le bilan.';
      case AppointmentStatus.cancelledByPatient:
        return 'Le bilan n’est pas disponible pour un rendez-vous annulé par le patient.';
      case AppointmentStatus.cancelledByProfessional:
        return 'Le bilan n’est pas disponible pour un rendez-vous annulé par le professionnel.';
      case AppointmentStatus.declinedByProfessional:
        return 'Le bilan n’est pas disponible pour une demande refusée.';
      case AppointmentStatus.noShow:
        return 'Le bilan n’est pas disponible lorsqu’une absence patient a été signalée.';
      case AppointmentStatus.completed:
        return 'Le bilan est disponible pour ce rendez-vous réalisé.';
    }
  }

  String _teleconsultationLockedMessage(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'La téléconsultation sera disponible après confirmation du rendez-vous.';
      case AppointmentStatus.confirmed:
        return 'La téléconsultation peut être créée ou ouverte pour ce rendez-vous confirmé.';
      case AppointmentStatus.completed:
        return 'Ce rendez-vous est déjà réalisé. Une téléconsultation existante reste consultable, mais aucune nouvelle session ne sera créée.';
      case AppointmentStatus.cancelledByPatient:
        return 'La téléconsultation n’est pas disponible pour un rendez-vous annulé par le patient.';
      case AppointmentStatus.cancelledByProfessional:
        return 'La téléconsultation n’est pas disponible pour un rendez-vous annulé par le professionnel.';
      case AppointmentStatus.declinedByProfessional:
        return 'La téléconsultation n’est pas disponible pour une demande refusée.';
      case AppointmentStatus.noShow:
        return 'La téléconsultation n’est pas disponible lorsqu’une absence patient a été signalée.';
    }
  }

  void _openReport(BuildContext context, Appointment appointment) {
    if (!_canWriteReport(appointment)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_reportLockedMessage(appointment)),
          ),
        );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.professionalAppointmentReport,
      arguments: ProfessionalAppointmentReportArgs(
        appointmentId: appointment.id,
      ),
    );
  }

  Future<void> _openTeleconsultation(
    BuildContext context,
    WidgetRef ref, {
    required Appointment appointment,
    required TeleconsultationSession? existingSession,
  }) async {
    if (existingSession != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.teleconsultationDetail,
        arguments: TeleconsultationDetailArgs(
          sessionId: existingSession.id,
        ),
      );
      return;
    }

    if (!_canCreateTeleconsultation(appointment)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_teleconsultationLockedMessage(appointment)),
          ),
        );
      return;
    }

    try {
      final session = await ref
          .read(teleconsultationControllerProvider)
          .ensureForAppointment(
            appointmentId: appointment.id,
          );

      if (!context.mounted) return;

      Navigator.of(context).pushNamed(
        AppRoutes.teleconsultationDetail,
        arguments: TeleconsultationDetailArgs(
          sessionId: session.id,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de créer ou d’ouvrir la téléconsultation.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedId = appointmentId.trim();

    if (normalizedId.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyStateView(
            icon: Icons.search_off_outlined,
            title: 'Rendez-vous introuvable',
            message: 'Aucun identifiant rendez-vous valide n’a été fourni.',
          ),
        ),
      );
    }

    final authState = ref.watch(authControllerProvider);
    final appointmentAsync = ref.watch(appointmentByIdProvider(normalizedId));
    final profile = ref.watch(professionalProfileProvider);

    if (!authState.isAuthenticated || !authState.isProfessional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détail rendez-vous pro'),
        ),
        body: const SafeArea(
          child: EmptyStateView(
            icon: Icons.lock_outline,
            title: 'Accès réservé',
            message:
                'Vous devez être connecté avec un compte professionnel pour accéder à cette page.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail rendez-vous pro'),
      ),
      body: SafeArea(
        child: appointmentAsync.when(
          data: (appointment) {
            if (appointment == null) {
              return const EmptyStateView(
                icon: Icons.search_off_outlined,
                title: 'Rendez-vous introuvable',
                message: 'Ce rendez-vous n’existe pas ou n’est plus disponible.',
              );
            }

            if (!_belongsToProfessional(
              appointment: appointment,
              profile: profile,
              authUser: authState.user,
            )) {
              return const EmptyStateView(
                icon: Icons.lock_outline,
                title: 'Accès non autorisé',
                message:
                    'Ce rendez-vous ne correspond pas au professionnel actif.',
              );
            }

            final reportAsync = ref.watch(
              appointmentReportByAppointmentIdProvider(appointment.id),
            );

            final teleconsultationAsync = ref.watch(
              teleconsultationByAppointmentIdProvider(appointment.id),
            );

            final canConfirm =
                AppointmentUiHelpers.canProfessionalConfirm(appointment);
            final canDecline =
                AppointmentUiHelpers.canProfessionalDecline(appointment);
            final canCancelConfirmed =
                AppointmentUiHelpers.canProfessionalCancelConfirmed(appointment);
            final canComplete =
                AppointmentUiHelpers.canProfessionalComplete(appointment);
            final canMarkNoShow =
                AppointmentUiHelpers.canProfessionalMarkNoShow(appointment);

            final canWriteReport = _canWriteReport(appointment);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(appointment: appointment),
                const SizedBox(height: 14),
                _ActionHintCard(appointment: appointment),
                const SizedBox(height: 14),
                _ActionAvailabilityCard(
                  canConfirm: canConfirm,
                  canDecline: canDecline,
                  canCancelConfirmed: canCancelConfirmed,
                  canComplete: canComplete,
                  canMarkNoShow: canMarkNoShow,
                ),
                const SizedBox(height: 14),
                teleconsultationAsync.when(
                  data: (session) => _TeleconsultationStatusCard(
                    session: session,
                    lockedMessage: session == null &&
                            !_canCreateTeleconsultation(appointment)
                        ? _teleconsultationLockedMessage(appointment)
                        : null,
                    onOpen: () => _openTeleconsultation(
                      context,
                      ref,
                      appointment: appointment,
                      existingSession: session,
                    ),
                  ),
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Chargement de la téléconsultation...'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  error: (_, _) => _TeleconsultationStatusCard(
                    session: null,
                    lockedMessage: _canCreateTeleconsultation(appointment)
                        ? null
                        : _teleconsultationLockedMessage(appointment),
                    onOpen: () => _openTeleconsultation(
                      context,
                      ref,
                      appointment: appointment,
                      existingSession: null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                reportAsync.when(
                  data: (report) => _ReportStatusCard(
                    hasReport: report != null,
                    updatedAt: report?.updatedAt,
                    onOpen: canWriteReport
                        ? () => _openReport(context, appointment)
                        : null,
                    lockedMessage: canWriteReport
                        ? null
                        : _reportLockedMessage(appointment),
                  ),
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Chargement du bilan...'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  error: (_, _) => _ReportStatusCard(
                    hasReport: false,
                    updatedAt: null,
                    onOpen: canWriteReport
                        ? () => _openReport(context, appointment)
                        : null,
                    lockedMessage: canWriteReport
                        ? null
                        : _reportLockedMessage(appointment),
                  ),
                ),
                const SizedBox(height: 14),
                InfoSectionCard(
                  title: 'Rendez-vous',
                  icon: Icons.event_note_outlined,
                  children: [
                    InfoLine(
                      label: 'Date',
                      value:
                          '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}',
                    ),
                    InfoLine(
                      label: 'Motif',
                      value: appointment.reason,
                    ),
                    InfoLine(
                      label: 'Statut',
                      value: AppointmentUiHelpers.professionalStatusBadgeLabel(
                        appointment.status,
                      ),
                    ),
                    InfoLine(
                      label: 'Créé le',
                      value: AppDateFormatters.formatDateTimeLabel(
                        appointment.createdAt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InfoSectionCard(
                  title: 'Patient',
                  icon: Icons.person_outline,
                  children: [
                    InfoLine(
                      label: 'Nom',
                      value: appointment.patientFullName,
                    ),
                    InfoLine(
                      label: 'Téléphone',
                      value: appointment.patientPhoneE164,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InfoSectionCard(
                  title: 'Professionnel',
                  icon: Icons.medical_services_outlined,
                  children: [
                    InfoLine(
                      label: 'Nom',
                      value: appointment.practitionerName,
                    ),
                    InfoLine(
                      label: 'Spécialité',
                      value: appointment.specialty,
                    ),
                    InfoLine(
                      label: 'Adresse',
                      value: appointment.fullAddress,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InfoSectionCard(
                  title: 'Consentement',
                  icon: Icons.shield_outlined,
                  children: [
                    InfoLine(
                      label: 'Accepté',
                      value: appointment.consentAccepted ? 'Oui' : 'Non',
                    ),
                    InfoLine(
                      label: 'Version',
                      value: appointment.consentVersion,
                    ),
                    InfoLine(
                      label: 'Horodatage',
                      value: AppDateFormatters.formatDateTimeLabel(
                        appointment.consentAcceptedAt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (canWriteReport)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _openReport(context, appointment),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Rédiger / modifier le bilan'),
                    ),
                  ),
                if (!canWriteReport)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _reportLockedMessage(appointment),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _ProfessionalActionsSection(
                  canConfirm: canConfirm,
                  canDecline: canDecline,
                  canCancelConfirmed: canCancelConfirmed,
                  canComplete: canComplete,
                  canMarkNoShow: canMarkNoShow,
                  onConfirm: canConfirm
                      ? () => _confirmStatusChange(
                            context,
                            ref,
                            appointment: appointment,
                            newStatus: AppointmentStatus.confirmed,
                            title: 'Confirmer le rendez-vous',
                            message:
                                'Souhaitez-vous confirmer ce rendez-vous pour ${appointment.patientFullName} ?',
                            confirmLabel: 'Confirmer',
                            successMessage: 'Rendez-vous confirmé.',
                          )
                      : null,
                  onDecline: canDecline
                      ? () => _confirmStatusChange(
                            context,
                            ref,
                            appointment: appointment,
                            newStatus:
                                AppointmentStatus.declinedByProfessional,
                            title: 'Refuser la demande',
                            message:
                                'Souhaitez-vous refuser cette demande de rendez-vous pour ${appointment.patientFullName} ?',
                            confirmLabel: 'Refuser',
                            successMessage: 'Demande refusée.',
                          )
                      : null,
                  onCancelConfirmed: canCancelConfirmed
                      ? () => _confirmStatusChange(
                            context,
                            ref,
                            appointment: appointment,
                            newStatus:
                                AppointmentStatus.cancelledByProfessional,
                            title: 'Annuler le rendez-vous',
                            message:
                                'Souhaitez-vous annuler ce rendez-vous pour ${appointment.patientFullName} ?',
                            confirmLabel: 'Annuler le RDV',
                            successMessage: 'Rendez-vous annulé.',
                          )
                      : null,
                  onComplete: canComplete
                      ? () => _confirmStatusChange(
                            context,
                            ref,
                            appointment: appointment,
                            newStatus: AppointmentStatus.completed,
                            title: 'Marquer comme réalisé',
                            message:
                                'Confirmez-vous que le rendez-vous avec ${appointment.patientFullName} a bien été réalisé ?',
                            confirmLabel: 'Marquer réalisé',
                            successMessage: 'Rendez-vous marqué comme réalisé.',
                          )
                      : null,
                  onMarkNoShow: canMarkNoShow
                      ? () => _confirmStatusChange(
                            context,
                            ref,
                            appointment: appointment,
                            newStatus: AppointmentStatus.noShow,
                            title: 'Signaler une absence patient',
                            message:
                                'Confirmez-vous que ${appointment.patientFullName} ne s’est pas présenté à ce rendez-vous ?',
                            confirmLabel: 'Signaler absent',
                            successMessage: 'Absence patient signalée.',
                          )
                      : null,
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => ErrorStateView(
            message: 'Erreur : $error',
          ),
        ),
      ),
    );
  }
}

class _TeleconsultationStatusCard extends StatelessWidget {
  const _TeleconsultationStatusCard({
    required this.session,
    required this.lockedMessage,
    required this.onOpen,
  });

  final TeleconsultationSession? session;
  final String? lockedMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSession = session != null;

    final title = hasSession
        ? 'Téléconsultation disponible'
        : 'Téléconsultation';

    final message = hasSession
        ? 'Une session de téléconsultation est associée à ce rendez-vous.'
        : 'Créer une session de téléconsultation pour ce rendez-vous confirmé.';

    final statusLabel = session == null ? null : _teleconsultationStatusLabel(session!.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.video_call_outlined,
              color: cs.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniBadge(label: statusLabel),
                        if (session!.consentAccepted)
                          const _MiniBadge(label: 'Consentement accepté')
                        else
                          const _MiniBadge(label: 'Consentement requis'),
                      ],
                    ),
                  ],
                  if (lockedMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      lockedMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: hasSession
                  ? 'Ouvrir la téléconsultation'
                  : 'Créer la téléconsultation',
              onPressed: onOpen,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReportStatusCard extends StatelessWidget {
  const _ReportStatusCard({
    required this.hasReport,
    required this.updatedAt,
    required this.onOpen,
    required this.lockedMessage,
  });

  final bool hasReport;
  final DateTime? updatedAt;
  final VoidCallback? onOpen;
  final String? lockedMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final message = hasReport
        ? 'Un bilan est déjà enregistré pour ce rendez-vous.'
        : 'Aucun bilan n’a encore été saisi pour ce rendez-vous.';

    final updatedLabel = updatedAt == null
        ? null
        : 'Dernière mise à jour : ${updatedAt!.day.toString().padLeft(2, '0')}/${updatedAt!.month.toString().padLeft(2, '0')}/${updatedAt!.year} à ${updatedAt!.hour.toString().padLeft(2, '0')}:${updatedAt!.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasReport ? Icons.task_alt_outlined : Icons.edit_note_outlined,
              color: cs.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bilan du rendez-vous',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  if (updatedLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      updatedLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (lockedMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      lockedMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (onOpen != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: hasReport ? 'Modifier le bilan' : 'Créer le bilan',
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.people_outline,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.patientFullName,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.patientPhoneE164,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppointmentStatusBadge(
                        status: appointment.status,
                        isProfessional: true,
                      ),
                      AppointmentTemporalBadge(
                        appointment: appointment,
                        isProfessional: true,
                      ),
                      AppointmentDayHintBadge(appointment: appointment),
                    ],
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

class _ActionHintCard extends StatelessWidget {
  const _ActionHintCard({
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = AppointmentUiHelpers.professionalActionTitle(appointment);
    final message = AppointmentUiHelpers.professionalActionMessage(appointment);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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

class _ActionAvailabilityCard extends StatelessWidget {
  const _ActionAvailabilityCard({
    required this.canConfirm,
    required this.canDecline,
    required this.canCancelConfirmed,
    required this.canComplete,
    required this.canMarkNoShow,
  });

  final bool canConfirm;
  final bool canDecline;
  final bool canCancelConfirmed;
  final bool canComplete;
  final bool canMarkNoShow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = <String>[
      if (canConfirm) 'Confirmation disponible',
      if (canDecline) 'Refus disponible',
      if (canCancelConfirmed) 'Annulation du rendez-vous disponible',
      if (canComplete) 'Clôture comme réalisé disponible',
      if (canMarkNoShow) 'Signalement d’absence disponible',
      if (!canConfirm &&
          !canDecline &&
          !canCancelConfirmed &&
          !canComplete &&
          !canMarkNoShow)
        'Aucune action disponible actuellement',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions disponibles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  ...actions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $action',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
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

class _ProfessionalActionsSection extends StatelessWidget {
  const _ProfessionalActionsSection({
    required this.canConfirm,
    required this.canDecline,
    required this.canCancelConfirmed,
    required this.canComplete,
    required this.canMarkNoShow,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancelConfirmed,
    required this.onComplete,
    required this.onMarkNoShow,
  });

  final bool canConfirm;
  final bool canDecline;
  final bool canCancelConfirmed;
  final bool canComplete;
  final bool canMarkNoShow;

  final VoidCallback? onConfirm;
  final VoidCallback? onDecline;
  final VoidCallback? onCancelConfirmed;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkNoShow;

  @override
  Widget build(BuildContext context) {
    final hasAnyAction = canConfirm ||
        canDecline ||
        canCancelConfirmed ||
        canComplete ||
        canMarkNoShow;

    if (!hasAnyAction) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (canConfirm)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer le rendez-vous'),
            ),
          ),
        if (canConfirm &&
            (canDecline ||
                canCancelConfirmed ||
                canComplete ||
                canMarkNoShow))
          const SizedBox(height: 10),
        if (canDecline)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onDecline,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Refuser la demande'),
            ),
          ),
        if (canDecline &&
            (canCancelConfirmed || canComplete || canMarkNoShow))
          const SizedBox(height: 10),
        if (canCancelConfirmed)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCancelConfirmed,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Annuler le rendez-vous'),
            ),
          ),
        if (canCancelConfirmed && (canComplete || canMarkNoShow))
          const SizedBox(height: 10),
        if (canComplete)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Marquer comme réalisé'),
            ),
          ),
        if (canComplete && canMarkNoShow) const SizedBox(height: 10),
        if (canMarkNoShow)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onMarkNoShow,
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Signaler patient absent'),
            ),
          ),
      ],
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

String _teleconsultationStatusLabel(TeleconsultationStatus status) {
  switch (status) {
    case TeleconsultationStatus.scheduled:
      return 'Programmée';
    case TeleconsultationStatus.waiting:
      return 'En attente';
    case TeleconsultationStatus.inProgress:
      return 'En cours';
    case TeleconsultationStatus.completed:
      return 'Terminée';
    case TeleconsultationStatus.cancelled:
      return 'Annulée';
  }
}