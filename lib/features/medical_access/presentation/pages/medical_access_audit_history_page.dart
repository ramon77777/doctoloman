import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/medical_access_audit.dart';
import '../providers/medical_access_audit_providers.dart';

class MedicalAccessAuditHistoryPage extends ConsumerWidget {
  const MedicalAccessAuditHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authControllerProvider).user;
    final auditsAsync = ref.watch(medicalAccessAuditListProvider);

    final patientId = _normalizePatientId(authUser?.phone ?? '');

    Future<void> onRefresh() async {
      ref.invalidate(medicalAccessAuditListProvider);
      await ref.read(medicalAccessAuditListProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des accès'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(medicalAccessAuditListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: auditsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _AuditErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(medicalAccessAuditListProvider),
          ),
          data: (items) {
            if (patientId.isEmpty) {
              return const _AuditMessageState(
                icon: Icons.lock_outline,
                title: 'Compte patient indisponible',
                message:
                    'Impossible de charger l’historique des accès pour ce compte.',
              );
            }

            final filtered = items.where((item) {
              return _normalizePatientId(item.patientId) == patientId;
            }).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (filtered.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    _AuditInfoCard(
                      title: 'Traçabilité des accès',
                      message:
                          'Cette page liste les consultations effectuées par des professionnels autorisés sur votre dossier médical.',
                    ),
                    SizedBox(height: 24),
                    _AuditMessageCard(
                      icon: Icons.history_toggle_off,
                      title: 'Aucun accès journalisé',
                      message:
                          'Aucune consultation de votre dossier médical n’a encore été enregistrée dans cette version.',
                    ),
                  ],
                ),
              );
            }

            final folderOpenCount = filtered.where((item) {
              return item.action ==
                  MedicalAccessAuditAction.openPatientMedicalRecords;
            }).length;

            final documentOpenCount = filtered.where((item) {
              return item.action == MedicalAccessAuditAction.openMedicalRecord;
            }).length;

            final uniqueProfessionals = filtered
                .map((item) => item.professionalName.trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .length;

            final latestAccess = filtered.first.createdAt;

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _AuditInfoCard(
                    title: 'Traçabilité des accès',
                    message:
                        'Cette page liste les consultations effectuées par des professionnels autorisés sur votre dossier médical.',
                  ),
                  const SizedBox(height: 14),
                  _AuditSummaryCard(
                    totalCount: filtered.length,
                    folderOpenCount: folderOpenCount,
                    documentOpenCount: documentOpenCount,
                    uniqueProfessionalsCount: uniqueProfessionals,
                    latestAccessAt: latestAccess,
                  ),
                  const SizedBox(height: 14),
                  ...filtered.map(
                    (audit) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AuditItemCard(audit: audit),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _normalizePatientId(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}

class _AuditInfoCard extends StatelessWidget {
  const _AuditInfoCard({
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

class _AuditSummaryCard extends StatelessWidget {
  const _AuditSummaryCard({
    required this.totalCount,
    required this.folderOpenCount,
    required this.documentOpenCount,
    required this.uniqueProfessionalsCount,
    required this.latestAccessAt,
  });

  final int totalCount;
  final int folderOpenCount;
  final int documentOpenCount;
  final int uniqueProfessionalsCount;
  final DateTime latestAccessAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AuditBadge(
                  label: '$totalCount accès journalisé(s)',
                  colorScheme: cs,
                ),
                _AuditBadge(
                  label: '$folderOpenCount ouverture(s) du dossier',
                  colorScheme: cs,
                ),
                _AuditBadge(
                  label: '$documentOpenCount document(s) consulté(s)',
                  colorScheme: cs,
                ),
                _AuditBadge(
                  label: '$uniqueProfessionalsCount professionnel(s)',
                  colorScheme: cs,
                ),
                _AuditBadge(
                  label: 'Dernier accès : ${_formatDateTime(latestAccessAt)}',
                  colorScheme: cs,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Chaque consultation enregistrée ici contribue à la traçabilité du dossier médical du patient.',
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditItemCard extends StatelessWidget {
  const _AuditItemCard({
    required this.audit,
  });

  final MedicalAccessAudit audit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = _titleFor(audit);
    final subtitle = _subtitleFor(audit);
    final icon = _iconFor(audit.action);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AuditBadge(
                        label: audit.professionalName.trim().isEmpty
                            ? 'Professionnel non renseigné'
                            : audit.professionalName,
                        colorScheme: cs,
                      ),
                      _AuditBadge(
                        label: _formatDateTime(audit.createdAt),
                        colorScheme: cs,
                      ),
                      if (audit.medicalRecordTitle != null &&
                          audit.medicalRecordTitle!.trim().isNotEmpty)
                        _AuditBadge(
                          label: audit.medicalRecordTitle!,
                          colorScheme: cs,
                        ),
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

  String _titleFor(MedicalAccessAudit audit) {
    switch (audit.action) {
      case MedicalAccessAuditAction.openPatientMedicalRecords:
        return 'Consultation du dossier médical';
      case MedicalAccessAuditAction.openMedicalRecord:
        return 'Consultation d’un document médical';
    }
  }

  String _subtitleFor(MedicalAccessAudit audit) {
    switch (audit.action) {
      case MedicalAccessAuditAction.openPatientMedicalRecords:
        return '${audit.professionalName} a ouvert votre dossier médical.';
      case MedicalAccessAuditAction.openMedicalRecord:
        final doc = audit.medicalRecordTitle?.trim();
        if (doc == null || doc.isEmpty) {
          return '${audit.professionalName} a consulté un document de votre dossier.';
        }
        return '${audit.professionalName} a consulté le document : $doc';
    }
  }

  IconData _iconFor(MedicalAccessAuditAction action) {
    switch (action) {
      case MedicalAccessAuditAction.openPatientMedicalRecords:
        return Icons.folder_shared_outlined;
      case MedicalAccessAuditAction.openMedicalRecord:
        return Icons.description_outlined;
    }
  }
}

class _AuditBadge extends StatelessWidget {
  const _AuditBadge({
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

class _AuditMessageCard extends StatelessWidget {
  const _AuditMessageCard({
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 42, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
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

class _AuditMessageState extends StatelessWidget {
  const _AuditMessageState({
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
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
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

class _AuditErrorState extends StatelessWidget {
  const _AuditErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Erreur',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final mon = value.month.toString().padLeft(2, '0');
  return '$dd/$mon/${value.year} à $hh:$mm';
}