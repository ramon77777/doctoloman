import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/ui/info_widgets.dart';
import '../../../appointment_reports/domain/appointment_report.dart';
import '../../../appointment_reports/presentation/providers/appointment_reports_providers.dart';
import '../../../professional_schedule/domain/professional_schedule.dart';
import '../../../professional_schedule/domain/slot_generation.dart';
import '../../../professional_schedule/presentation/providers/professional_schedule_providers.dart';
import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';
import '../helpers/appointment_ui_helpers.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_badges.dart';

class AppointmentDetailPage extends ConsumerWidget {
  const AppointmentDetailPage({
    super.key,
    required this.appointmentId,
  });

  final String appointmentId;

  Future<void> _cancelAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final isPending = appointment.status == AppointmentStatus.pending;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text(
                isPending ? 'Annuler la demande' : 'Annuler le rendez-vous',
              ),
              content: Text(
                isPending
                    ? 'Souhaites-tu vraiment annuler cette demande de rendez-vous ?'
                    : 'Souhaites-tu vraiment annuler ce rendez-vous ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Non'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Oui, annuler'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;
    if (!context.mounted) return;

    await ref.read(appointmentsControllerProvider).updateStatus(
          id: appointment.id,
          status: AppointmentStatus.cancelledByPatient,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPending ? 'Demande annulée.' : 'Rendez-vous annulé.',
        ),
      ),
    );
  }

  Future<void> _rescheduleAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final result = await showDialog<_RescheduleSelection>(
      context: context,
      builder: (ctx) => _RescheduleDialog(appointment: appointment),
    );

    if (result == null) return;

    try {
      final updated = await ref.read(appointmentsControllerProvider).reschedule(
            id: appointment.id,
            day: result.day,
            slot: result.slot,
          );

      if (!context.mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de reprogrammer ce rendez-vous.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rendez-vous reprogrammé au '
            '${AppDateFormatters.formatShortDate(updated.day)} à ${updated.slot}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      if (e is AppointmentSlotUnavailableException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce nouveau créneau vient d’être réservé. Choisis-en un autre.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de reprogrammer le rendez-vous.'),
        ),
      );
    }
  }

  void _showReminderInfo(BuildContext context, Appointment appointment) {
    final message = switch (appointment.status) {
      AppointmentStatus.cancelledByPatient =>
        'Les rappels ne sont pas disponibles pour un rendez-vous annulé par vous.',
      AppointmentStatus.declinedByProfessional =>
        'Les rappels ne sont pas disponibles pour une demande refusée par le professionnel.',
      AppointmentStatus.pending =>
        'Votre demande a bien été envoyée. Les rappels seront disponibles après confirmation par le professionnel.',
      AppointmentStatus.confirmed =>
        appointment.isUpcoming
            ? 'Ce rendez-vous est confirmé. Les rappels automatiques seront bientôt disponibles.'
            : 'Ce rendez-vous est passé. Aucun rappel nécessaire.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(appointmentByIdProvider(appointmentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du rendez-vous'),
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

            final reportAsync = ref.watch(
              appointmentReportByAppointmentIdProvider(appointment.id),
            );

            final canCancel = AppointmentUiHelpers.canPatientCancel(appointment);
            final canReschedule =
                AppointmentUiHelpers.canPatientReschedule(appointment);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(appointment: appointment),
                const SizedBox(height: 14),
                _ActionSummaryCard(appointment: appointment),
                const SizedBox(height: 14),
                _ReminderCard(
                  appointment: appointment,
                  onTap: () => _showReminderInfo(context, appointment),
                ),
                const SizedBox(height: 14),
                _ActionAvailabilityCard(
                  appointment: appointment,
                  canCancel: canCancel,
                  canReschedule: canReschedule,
                ),
                const SizedBox(height: 14),
                InfoSectionCard(
                  title: 'Informations du rendez-vous',
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
                      value: AppointmentUiHelpers.statusLabel(
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
                const SizedBox(height: 14),
                reportAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Chargement du compte rendu de consultation...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _PatientReportInfoMessage(
                        icon: Icons.error_outline,
                        title: 'Compte rendu indisponible',
                        message:
                            'Impossible de charger le compte rendu : $error',
                      ),
                    ),
                  ),
                  data: (report) => _PatientAppointmentReportSection(
                    appointment: appointment,
                    report: report,
                  ),
                ),
                if (canReschedule) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _rescheduleAppointment(context, ref, appointment),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Reprogrammer'),
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _cancelAppointment(context, ref, appointment),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(
                        appointment.status == AppointmentStatus.pending
                            ? 'Annuler cette demande'
                            : 'Annuler ce rendez-vous',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => ErrorStateView(
            message: '$e',
          ),
        ),
      ),
    );
  }
}

class _ActionSummaryCard extends StatelessWidget {
  const _ActionSummaryCard({
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = AppointmentUiHelpers.patientReminderTitle(appointment);
    final subtitle = AppointmentUiHelpers.patientReminderSubtitle(appointment);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insights_outlined, color: cs.primary),
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
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
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
    required this.appointment,
    required this.canCancel,
    required this.canReschedule,
  });

  final Appointment appointment;
  final bool canCancel;
  final bool canReschedule;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final actions = <String>[
      if (canReschedule) 'Reprogrammation disponible',
      if (canCancel)
        appointment.status == AppointmentStatus.pending
            ? 'Annulation de la demande disponible'
            : 'Annulation du rendez-vous disponible',
      if (!canReschedule && !canCancel) 'Aucune action disponible actuellement',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_outlined, color: cs.primary),
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
                              color: cs.onSurfaceVariant,
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

class _PatientAppointmentReportSection extends StatelessWidget {
  const _PatientAppointmentReportSection({
    required this.appointment,
    required this.report,
  });

  final Appointment appointment;
  final AppointmentReport? report;

  String _linkedMedicalRecordId(String appointmentId) {
    return 'report_${appointmentId.trim()}';
  }

  void _openLinkedMedicalRecord(BuildContext context, Appointment appointment) {
    Navigator.of(context).pushNamed(
      AppRoutes.medicalRecordDetail,
      arguments: MedicalRecordDetailArgs(
        recordId: _linkedMedicalRecordId(appointment.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (appointment.status == AppointmentStatus.pending) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: _PatientReportInfoMessage(
            icon: Icons.hourglass_bottom_outlined,
            title: 'Compte rendu non disponible',
            message:
                'Le compte rendu sera disponible après confirmation et saisie par le professionnel.',
          ),
        ),
      );
    }

    if (appointment.status == AppointmentStatus.declinedByProfessional ||
        appointment.status == AppointmentStatus.cancelledByPatient) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: _PatientReportInfoMessage(
            icon: Icons.event_busy_outlined,
            title: 'Compte rendu indisponible',
            message:
                'Aucun compte rendu n’est disponible pour une demande refusée ou un rendez-vous annulé.',
          ),
        ),
      );
    }

    final currentReport = report;

    if (currentReport == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: _PatientReportInfoMessage(
            icon: Icons.note_alt_outlined,
            title: 'Compte rendu non encore disponible',
            message:
                'Le professionnel n’a pas encore renseigné le compte rendu de cette consultation.',
          ),
        ),
      );
    }

    final sections = <_PatientReportSectionData>[
      if (currentReport.hasSummary)
        _PatientReportSectionData(
          title: 'Résumé',
          value: currentReport.summary,
          icon: Icons.summarize_outlined,
        ),
      if (currentReport.hasClinicalNotes)
        _PatientReportSectionData(
          title: 'Notes cliniques',
          value: currentReport.clinicalNotes,
          icon: Icons.notes_outlined,
        ),
      if (currentReport.hasDiagnosis)
        _PatientReportSectionData(
          title: 'Diagnostic',
          value: currentReport.diagnosis,
          icon: Icons.medical_information_outlined,
        ),
      if (currentReport.hasTreatmentPlan)
        _PatientReportSectionData(
          title: 'Conduite à tenir',
          value: currentReport.treatmentPlan,
          icon: Icons.assignment_turned_in_outlined,
        ),
      if (currentReport.hasPrescriptions)
        _PatientReportSectionData(
          title: 'Prescription',
          value: currentReport.prescriptions,
          icon: Icons.receipt_long_outlined,
        ),
      if (currentReport.hasRequestedExams)
        _PatientReportSectionData(
          title: 'Examens demandés',
          value: currentReport.requestedExams,
          icon: Icons.science_outlined,
        ),
      if (currentReport.hasFollowUpInstructions)
        _PatientReportSectionData(
          title: 'Consignes de suivi',
          value: currentReport.followUpInstructions,
          icon: Icons.follow_the_signs_outlined,
        ),
    ];

    return InfoSectionCard(
      title: 'Compte rendu de consultation',
      icon: Icons.description_outlined,
      children: [
        InfoLine(
          label: 'Professionnel',
          value: currentReport.professionalName,
        ),
        InfoLine(
          label: 'Mis à jour',
          value: AppDateFormatters.formatDateTimeLabel(currentReport.updatedAt),
        ),
        InfoLine(
          label: 'Motif initial',
          value: currentReport.appointmentReason,
        ),
        const SizedBox(height: 8),
        if (sections.isEmpty)
          const Text(
            'Le compte rendu existe, mais aucun contenu détaillé n’a encore été renseigné.',
          )
        else
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PatientReportTextBlock(section: section),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openLinkedMedicalRecord(context, appointment),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Voir dans mon dossier médical'),
          ),
        ),
      ],
    );
  }
}

class _PatientReportInfoMessage extends StatelessWidget {
  const _PatientReportInfoMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientReportSectionData {
  const _PatientReportSectionData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _PatientReportTextBlock extends StatelessWidget {
  const _PatientReportTextBlock({
    required this.section,
  });

  final _PatientReportSectionData section;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(section.icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                section.value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RescheduleSelection {
  const _RescheduleSelection({
    required this.day,
    required this.slot,
  });

  final DateTime day;
  final String slot;
}

class _RescheduleDialog extends ConsumerStatefulWidget {
  const _RescheduleDialog({
    required this.appointment,
  });

  final Appointment appointment;

  @override
  ConsumerState<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  late DateTime _selectedDay;
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().isAfter(widget.appointment.day)
        ? DateTime.now()
        : widget.appointment.day;
    _selectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
  }

  DaySchedule? _scheduleForSelectedDay(List<DaySchedule> schedules) {
    for (final day in schedules) {
      if (day.weekday == _selectedDay.weekday) {
        return day;
      }
    }
    return null;
  }

  String? _extractSlotStart(String displaySlot) {
    final normalized = displaySlot.trim();
    if (normalized.isEmpty) return null;

    final parts = normalized.split(' - ');
    if (parts.length != 2) return null;

    final start = parts.first.trim();
    return start.isEmpty ? null : start;
  }

  bool _isSameAppointmentDisplaySlot(String displaySlot) {
    final start = _extractSlotStart(displaySlot);
    if (start == null) return false;
    return start == widget.appointment.slot;
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(
      practitionerScheduleProvider(widget.appointment.practitionerId),
    );

    final schedule = _scheduleForSelectedDay(schedules);

    final rawSlotResult = schedule == null
        ? const SlotGenerationResult(
            isOpen: false,
            slots: [],
          )
        : buildSlotsForDay(
            schedule: schedule,
            selectedDay: _selectedDay,
            minimumLeadTimeMinutes: 0,
          );

    final takenSlotsAsync = ref.watch(
      takenSlotsForPractitionerDayProvider(
        TakenSlotsQuery(
          practitionerId: widget.appointment.practitionerId,
          day: _selectedDay,
        ),
      ),
    );

    return AlertDialog(
      title: const Text('Reprogrammer'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactDayPicker(
                selected: _selectedDay,
                onSelect: (day) {
                  setState(() {
                    _selectedDay = day;
                    _selectedSlot = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (schedule != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(schedule.summary),
                ),
              const SizedBox(height: 12),
              takenSlotsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('$e'),
                data: (takenSlots) {
                  final availableSlots =
                      rawSlotResult.slots.where((displaySlot) {
                    final isCurrentSameDay = AppDateFormatters.isSameCalendarDay(
                      _selectedDay,
                      widget.appointment.day,
                    );
                    final isCurrentSameSlot =
                        _isSameAppointmentDisplaySlot(displaySlot);

                    if (isCurrentSameDay && isCurrentSameSlot) {
                      return true;
                    }

                    final start = _extractSlotStart(displaySlot);
                    if (start == null) {
                      return false;
                    }

                    return !takenSlots.contains(start);
                  }).toList();

                  if (!rawSlotResult.isOpen) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Ce professionnel est fermé ce jour-là.',
                      ),
                    );
                  }

                  if (availableSlots.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun créneau disponible pour cette date.',
                      ),
                    );
                  }

                  final initialSelected = availableSlots.any(
                    (slot) => _isSameAppointmentDisplaySlot(slot),
                  )
                      ? availableSlots.firstWhere(
                          (slot) => _isSameAppointmentDisplaySlot(slot),
                        )
                      : null;

                  if (_selectedSlot == null && initialSelected != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _selectedSlot = initialSelected;
                      });
                    });
                  }

                  return _CompactSlotsGrid(
                    slots: availableSlots,
                    selectedSlot: _selectedSlot,
                    onSelect: (slot) {
                      setState(() {
                        _selectedSlot = slot;
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: _selectedSlot == null
              ? null
              : () {
                  final selectedDisplaySlot = _selectedSlot!;
                  final start = _extractSlotStart(selectedDisplaySlot);
                  if (start == null) {
                    return;
                  }

                  Navigator.of(context).pop(
                    _RescheduleSelection(
                      day: _selectedDay,
                      slot: start,
                    ),
                  );
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _CompactDayPicker extends StatelessWidget {
  const _CompactDayPicker({
    required this.selected,
    required this.onSelect,
  });

  final DateTime selected;
  final void Function(DateTime day) onSelect;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day).add(
        Duration(days: i),
      ),
    );

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = AppDateFormatters.isSameCalendarDay(d, selected);

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(d),
            child: Container(
              width: 68,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dowShort(d),
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dowShort(DateTime d) {
    const map = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mer',
      4: 'Jeu',
      5: 'Ven',
      6: 'Sam',
      7: 'Dim',
    };
    return map[d.weekday] ?? '';
  }
}

class _CompactSlotsGrid extends StatelessWidget {
  const _CompactSlotsGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  final List<String> slots;
  final String? selectedSlot;
  final void Function(String slot) onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: slots.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = slot == selectedSlot;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(slot),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Text(
              slot,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppointmentUiHelpers.patientReminderTitle(appointment),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppointmentUiHelpers.patientReminderSubtitle(appointment),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
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
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.event_available_outlined,
                color: cs.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.practitionerName,
                    style: t.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.specialty,
                    style: t.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppointmentStatusBadge(status: appointment.status),
                      AppointmentTemporalBadge(appointment: appointment),
                      AppointmentMiniBadge(
                        label: AppointmentUiHelpers.patientSectionLabel(
                          appointment,
                        ),
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