import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../medical_access/presentation/providers/medical_access_audit_providers.dart';
import '../../../medical_access/presentation/providers/medical_access_providers.dart';
import '../../domain/medical_record.dart';
import '../providers/medical_records_providers.dart';

class ProfessionalPatientMedicalRecordsPage extends ConsumerStatefulWidget {
  const ProfessionalPatientMedicalRecordsPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  ConsumerState<ProfessionalPatientMedicalRecordsPage> createState() =>
      _ProfessionalPatientMedicalRecordsPageState();
}

class _ProfessionalPatientMedicalRecordsPageState
    extends ConsumerState<ProfessionalPatientMedicalRecordsPage> {
  bool _auditLogged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authUser = ref.read(authControllerProvider).user;
    final professionalId = authUser?.id.trim() ?? '';

    if (_auditLogged || professionalId.isEmpty) return;

    final hasAccess = ref.read(
      hasMedicalAccessProvider(
        MedicalAccessQuery(
          patientId: widget.patientId,
          professionalId: professionalId,
        ),
      ),
    );

    if (!hasAccess) return;

    _auditLogged = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(medicalAccessAuditControllerProvider).logOpenPatientMedicalRecords(
            patientId: widget.patientId,
            patientName: widget.patientName,
          );
    });
  }

  void _openReadonlyRecord(MedicalRecord record) {
    final authUser = ref.read(authControllerProvider).user;
    final professionalId = authUser?.id.trim() ?? '';

    final hasAccess = ref.read(
      hasMedicalAccessProvider(
        MedicalAccessQuery(
          patientId: widget.patientId,
          professionalId: professionalId,
        ),
      ),
    );

    if (!hasAccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Accès non autorisé à ce dossier patient.',
            ),
          ),
        );
      return;
    }

    ref.read(medicalAccessAuditControllerProvider).logOpenMedicalRecord(
          patientId: widget.patientId,
          patientName: widget.patientName,
          medicalRecordId: record.id,
          medicalRecordTitle: record.title,
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProfessionalReadonlyMedicalRecordDetailPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
          record: record,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider).user;
    final professionalId = authUser?.id.trim() ?? '';

    final hasAccess = professionalId.isEmpty
        ? false
        : ref.watch(
            hasMedicalAccessProvider(
              MedicalAccessQuery(
                patientId: widget.patientId,
                professionalId: professionalId,
              ),
            ),
          );

    if (professionalId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.patientName),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Impossible de vérifier les autorisations du professionnel connecté.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.patientName),
        ),
        body: const SafeArea(
          child: _UnauthorizedAccessCard(),
        ),
      );
    }

    final recordsAsync = ref.watch(
      medicalRecordsByPatientIdProvider(widget.patientId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
      ),
      body: SafeArea(
        child: recordsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (records) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  title: 'Dossier médical autorisé',
                  message:
                      'Vous consultez les documents du patient ${widget.patientName} dans le cadre d’un accès explicitement accordé. Cette vue est en lecture seule.',
                ),
                const SizedBox(height: 14),
                _AccessGrantInfoCard(patientId: widget.patientId),
                const SizedBox(height: 14),
                _SummaryCard(
                  totalCount: records.length,
                  visibleCount: records.length,
                ),
                const SizedBox(height: 14),
                if (records.isEmpty)
                  const _EmptyStateCard(
                    title: 'Aucun document',
                    message:
                        'Ce patient ne possède encore aucun document médical disponible dans cette version.',
                  )
                else
                  ...records.map(
                    (record) {
                      final appointmentId =
                          _extractAppointmentIdFromRecord(record);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openReadonlyRecord(record),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.title,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.sourceLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    record.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _MiniBadge(
                                        label: _categoryLabel(record.category),
                                        colorScheme:
                                            Theme.of(context).colorScheme,
                                      ),
                                      _MiniBadge(
                                        label: _formatDate(record.recordDate),
                                        colorScheme:
                                            Theme.of(context).colorScheme,
                                      ),
                                      if (record.category ==
                                          MedicalRecordCategory.report)
                                        _MiniBadge(
                                          label: 'Bilan RDV',
                                          colorScheme:
                                              Theme.of(context).colorScheme,
                                        ),
                                      if (record.isSensitive)
                                        _MiniBadge(
                                          label: 'Sensible',
                                          colorScheme:
                                              Theme.of(context).colorScheme,
                                        ),
                                    ],
                                  ),
                                  if (appointmentId != null) ...[
                                    const SizedBox(height: 12),
                                    _OriginAppointmentButton(
                                      appointmentId: appointmentId,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _categoryLabel(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return 'Ordonnance';
      case MedicalRecordCategory.labResult:
        return 'Analyse';
      case MedicalRecordCategory.imaging:
        return 'Imagerie';
      case MedicalRecordCategory.certificate:
        return 'Certificat';
      case MedicalRecordCategory.report:
        return 'Compte rendu';
      case MedicalRecordCategory.other:
        return 'Document';
    }
  }
}

class _ProfessionalReadonlyMedicalRecordDetailPage extends ConsumerWidget {
  const _ProfessionalReadonlyMedicalRecordDetailPage({
    required this.patientId,
    required this.patientName,
    required this.record,
  });

  final String patientId;
  final String patientName;
  final MedicalRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAppointmentReport = record.category == MedicalRecordCategory.report;
    final appointmentId = _extractAppointmentIdFromRecord(record);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document patient'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                        _iconFor(record.category),
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
                            record.title,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.sourceLabel,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ReadonlyBadge(
                                label: _categoryLabel(record.category),
                              ),
                              _ReadonlyBadge(
                                label: _formatDate(record.recordDate),
                              ),
                              if (record.isSensitive)
                                const _ReadonlyBadge(label: 'Donnée sensible'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (appointmentId != null) ...[
              const SizedBox(height: 14),
              _ReadonlyOriginAppointmentCard(
                appointmentId: appointmentId,
              ),
            ],
            const SizedBox(height: 14),
            const _ReadonlyInfoSectionCard(
              title: 'Mode d’accès',
              icon: Icons.lock_outline,
              children: [
                Text(
                  'Ce document est consulté via un accès patient autorisé. Cette vue est strictement en lecture seule pour le professionnel.',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ReadonlyInfoSectionCard(
              title: 'Informations',
              icon: Icons.description_outlined,
              children: [
                _ReadonlyLine(label: 'Patient', value: patientName),
                _ReadonlyLine(label: 'Source', value: record.sourceLabel),
                _ReadonlyLine(
                  label: 'Date doc',
                  value: _formatDate(record.recordDate),
                ),
                _ReadonlyLine(
                  label: 'Ajouté le',
                  value: _formatDate(record.createdAt),
                ),
                _ReadonlyLine(
                  label: 'Catégorie',
                  value: _categoryLabel(record.category),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ReadonlyInfoSectionCard(
              title: isAppointmentReport ? 'Résumé du bilan' : 'Résumé',
              icon: isAppointmentReport
                  ? Icons.summarize_outlined
                  : Icons.notes_outlined,
              children: [
                Text(
                  record.summary.trim().isEmpty
                      ? 'Aucun résumé disponible.'
                      : record.summary.trim(),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            if (isAppointmentReport) ...[
              const SizedBox(height: 14),
              _ReadonlyAppointmentReportDetailsCard(
                description: record.description,
              ),
            ] else if (record.hasDescription) ...[
              const SizedBox(height: 14),
              _ReadonlyInfoSectionCard(
                title: 'Description',
                icon: Icons.notes_outlined,
                children: [
                  Text(
                    record.effectiveDescription,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _ReadonlyInfoSectionCard(
              title: 'Confidentialité',
              icon: Icons.shield_outlined,
              children: [
                Text(
                  'Ce document médical appartient au dossier du patient. Toute consultation doit rester strictement limitée au cadre de soin autorisé.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'En production, les données sensibles devront rester hébergées localement en Côte d’Ivoire, avec contrôle d’accès, consentement patient et journalisation.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return 'Ordonnance';
      case MedicalRecordCategory.labResult:
        return 'Analyse';
      case MedicalRecordCategory.imaging:
        return 'Imagerie';
      case MedicalRecordCategory.certificate:
        return 'Certificat';
      case MedicalRecordCategory.report:
        return 'Compte rendu';
      case MedicalRecordCategory.other:
        return 'Document';
    }
  }

  static IconData _iconFor(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return Icons.receipt_long_outlined;
      case MedicalRecordCategory.labResult:
        return Icons.science_outlined;
      case MedicalRecordCategory.imaging:
        return Icons.image_search_outlined;
      case MedicalRecordCategory.certificate:
        return Icons.verified_outlined;
      case MedicalRecordCategory.report:
        return Icons.article_outlined;
      case MedicalRecordCategory.other:
        return Icons.description_outlined;
    }
  }
}

class _OriginAppointmentButton extends ConsumerWidget {
  const _OriginAppointmentButton({
    required this.appointmentId,
  });

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(
      appointmentByIdProvider(appointmentId),
    );

    return appointmentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (appointment) {
        if (appointment == null) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.professionalAppointmentDetail,
                arguments: ProfessionalAppointmentDetailArgs(
                  appointmentId: appointmentId,
                ),
              );
            },
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('Ouvrir le rendez-vous d’origine'),
          ),
        );
      },
    );
  }
}

class _ReadonlyOriginAppointmentCard extends ConsumerWidget {
  const _ReadonlyOriginAppointmentCard({
    required this.appointmentId,
  });

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(
      appointmentByIdProvider(appointmentId),
    );

    return appointmentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (appointment) {
        if (appointment == null) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.professionalAppointmentDetail,
                    arguments: ProfessionalAppointmentDetailArgs(
                      appointmentId: appointmentId,
                    ),
                  );
                },
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Ouvrir le rendez-vous d’origine'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccessGrantInfoCard extends ConsumerWidget {
  const _AccessGrantInfoCard({
    required this.patientId,
  });

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(
      activeMedicalAccessForCurrentProfessionalByPatientIdProvider(patientId),
    );

    if (access == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.key_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Autorisation d’accès',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accès accordé le ${_formatDateTime(access.grantedAt)}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _UnauthorizedAccessCard extends StatelessWidget {
  const _UnauthorizedAccessCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Accès non autorisé',
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Vous ne disposez pas d’une autorisation active pour consulter ce dossier médical.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadonlyAppointmentReportDetailsCard extends StatelessWidget {
  const _ReadonlyAppointmentReportDetailsCard({
    required this.description,
  });

  final String? description;

  @override
  Widget build(BuildContext context) {
    final sections = _parseReportSections(description);

    return _ReadonlyInfoSectionCard(
      title: 'Détails du bilan',
      icon: Icons.medical_information_outlined,
      children: [
        if (sections.isEmpty)
          Text(
            'Aucun détail supplémentaire disponible.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ReadonlyReportSectionBlock(
                title: section.title,
                value: section.value,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadonlyReportSectionBlock extends StatelessWidget {
  const _ReadonlyReportSectionBlock({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ReadonlyInfoSectionCard extends StatelessWidget {
  const _ReadonlyInfoSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadonlyLine extends StatelessWidget {
  const _ReadonlyLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: cs.primary),
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
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.visibleCount,
  });

  final int totalCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniBadge(
              label: '$totalCount document(s)',
              colorScheme: cs,
            ),
            _MiniBadge(
              label: '$visibleCount affiché(s)',
              colorScheme: cs,
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
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReadonlyBadge extends StatelessWidget {
  const _ReadonlyBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 36,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedReportSection {
  const _ParsedReportSection({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;
}

List<_ParsedReportSection> _parseReportSections(String? rawDescription) {
  final raw = rawDescription?.trim() ?? '';
  if (raw.isEmpty) return const <_ParsedReportSection>[];

  final blocks = raw
      .split(RegExp(r'\n\s*\n'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);

  final sections = <_ParsedReportSection>[];

  for (final block in blocks) {
    final separatorIndex = block.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex >= block.length - 1) {
      sections.add(
        _ParsedReportSection(
          title: 'Information',
          value: block,
        ),
      );
      continue;
    }

    final title = block.substring(0, separatorIndex).trim();
    final value = block.substring(separatorIndex + 1).trim();

    sections.add(
      _ParsedReportSection(
        title: title.isEmpty ? 'Information' : title,
        value: value.isEmpty ? 'Non renseigné' : value,
      ),
    );
  }

  return sections;
}

String? _extractAppointmentIdFromRecord(MedicalRecord record) {
  final normalizedId = record.id.trim();
  if (!normalizedId.startsWith('report_')) {
    return null;
  }

  final appointmentId = normalizedId.substring('report_'.length).trim();
  return appointmentId.isEmpty ? null : appointmentId;
}

String _formatDate(DateTime d) {
  const months = [
    'janv',
    'févr',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sept',
    'oct',
    'nov',
    'déc',
  ];
  final month = months[d.month - 1];
  return '${d.day} $month ${d.year}';
}

String _formatDateTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final mon = value.month.toString().padLeft(2, '0');
  return '$dd/$mon/${value.year} à $hh:$mm';
}