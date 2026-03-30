import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../domain/medical_record.dart';
import '../providers/medical_records_providers.dart';

class MedicalRecordDetailPage extends ConsumerWidget {
  const MedicalRecordDetailPage({
    super.key,
    required this.recordId,
  });

  final String recordId;

  String _categoryLabel(MedicalRecordCategory category) {
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

  IconData _iconFor(MedicalRecordCategory category) {
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

  Future<void> _deleteRecord(
    BuildContext context,
    WidgetRef ref,
    String recordId,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer le document'),
            content: const Text(
              'Voulez-vous vraiment supprimer ce document médical ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await ref.read(medicalRecordsControllerProvider).deleteById(recordId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document supprimé.')),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedId = recordId.trim();

    if (normalizedId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détail du document'),
        ),
        body: const SafeArea(
          child: _MessageState(
            icon: Icons.search_off_outlined,
            title: 'Document introuvable',
            message: 'Aucun identifiant document valide n’a été fourni.',
          ),
        ),
      );
    }

    final recordAsync = ref.watch(medicalRecordByIdProvider(normalizedId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du document'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.medicalRecordEdit,
                arguments: MedicalRecordEditArgs(recordId: normalizedId),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _deleteRecord(context, ref, normalizedId),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: recordAsync.when(
          data: (record) {
            if (record == null) {
              return const _MessageState(
                icon: Icons.search_off_outlined,
                title: 'Document introuvable',
                message: 'Ce document n’existe pas ou n’est plus disponible.',
              );
            }

            final cs = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return ListView(
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
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _iconFor(record.category),
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
                                record.title,
                                style: textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.sourceLabel,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Badge(label: _categoryLabel(record.category)),
                                  _Badge(label: _formatDate(record.recordDate)),
                                  if (record.isSensitive)
                                    const _Badge(label: 'Donnée sensible'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _StatusCard(
                  categoryLabel: _categoryLabel(record.category),
                  isSensitive: record.isSensitive,
                  createdAt: record.createdAt,
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Informations',
                  icon: Icons.description_outlined,
                  children: [
                    _Line(label: 'Patient', value: record.patientName),
                    _Line(label: 'Source', value: record.sourceLabel),
                    _Line(
                      label: 'Date doc',
                      value: _formatDate(record.recordDate),
                    ),
                    _Line(
                      label: 'Ajouté le',
                      value: _formatDate(record.createdAt),
                    ),
                    _Line(
                      label: 'Catégorie',
                      value: _categoryLabel(record.category),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Résumé',
                  icon: Icons.notes_outlined,
                  children: [
                    Text(
                      record.summary.trim().isEmpty
                          ? 'Aucun résumé disponible.'
                          : record.summary.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Confidentialité',
                  icon: Icons.shield_outlined,
                  children: [
                    Text(
                      'Dans cette version, les documents mock sont conservés localement sur l’appareil.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En production, les données médicales sensibles devront rester hébergées localement en Côte d’Ivoire, avec contrôle d’accès, consentement patient et journalisation.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _MessageState(
            icon: Icons.error_outline,
            title: 'Erreur',
            message: '$error',
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.categoryLabel,
    required this.isSensitive,
    required this.createdAt,
  });

  final String categoryLabel;
  final bool isSensitive;
  final DateTime createdAt;

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
              'Statut du document',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(label: categoryLabel),
                _Badge(
                  label: isSensitive ? 'Accès sensible' : 'Accès standard',
                ),
                _Badge(label: 'Ajouté : ${_formatDate(createdAt)}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ce document fait partie du dossier médical numérique local de cette version de démonstration.',
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

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
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
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
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

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
                color: cs.onSurfaceVariant,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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