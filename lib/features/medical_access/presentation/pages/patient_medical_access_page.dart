import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../providers/medical_access_providers.dart';

class PatientMedicalAccessPage extends ConsumerWidget {
  const PatientMedicalAccessPage({super.key});

  Future<void> _grantAccess(
    BuildContext context,
    WidgetRef ref, {
    required ProfessionalProfile professional,
  }) async {
    final authUser = ref.read(authControllerProvider).user;
    if (authUser == null || authUser.role != AppUserRole.patient) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Autoriser l’accès'),
            content: Text(
              'Autoriser ${professional.displayName} à consulter votre dossier médical ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Autoriser'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await ref.read(medicalAccessControllerProvider).grantAccess(
          patientUser: authUser,
          patientName: authUser.name,
          professionalId: professional.id,
          professionalName: professional.displayName,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Accès autorisé pour ${professional.displayName}.',
          ),
        ),
      );
  }

  Future<void> _revokeAccess(
    BuildContext context,
    WidgetRef ref, {
    required String accessId,
    required String professionalName,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Révoquer l’accès'),
            content: Text(
              'Voulez-vous révoquer l’accès de $professionalName à votre dossier médical ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Révoquer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await ref.read(medicalAccessControllerProvider).revokeById(accessId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Accès révoqué pour $professionalName.',
          ),
        ),
      );
  }

  void _openAuditHistory(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.medicalAccessAuditHistory);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated ||
        user == null ||
        user.role != AppUserRole.patient) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Autorisations dossier médical'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté avec un compte patient pour accéder à cette page.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final activeAccesses = ref.watch(patientMedicalAccessProvider);
    final professionalsAsync = ref.watch(allProfessionalProfilesProvider);

    final activeProfessionalIds = activeAccesses
        .map((item) => item.professionalId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final professionals = professionalsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <ProfessionalProfile>[],
    );

    final availableProfessionals = professionals.where((profile) {
      return !activeProfessionalIds.contains(profile.id.trim());
    }).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autorisations dossier médical'),
        actions: [
          IconButton(
            tooltip: 'Historique des accès',
            onPressed: () => _openAuditHistory(context),
            icon: const Icon(Icons.manage_history_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _InfoCard(
              title: 'Contrôle d’accès',
              message:
                  'Vous restez maître de votre dossier. Vous pouvez autoriser ou révoquer l’accès d’un professionnel à tout moment.',
            ),
            const SizedBox(height: 14),
            _OverviewCard(
              activeCount: activeAccesses.length,
              availableCount: availableProfessionals.length,
              onOpenHistory: () => _openAuditHistory(context),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(
              title: 'Accès actifs',
              subtitle: 'Professionnels actuellement autorisés',
            ),
            const SizedBox(height: 10),
            if (activeAccesses.isEmpty)
              const _EmptyStateCard(
                icon: Icons.lock_outline,
                title: 'Aucun accès actif',
                message:
                    'Aucun professionnel n’a actuellement accès à votre dossier.',
              )
            else
              ...activeAccesses.map(
                (access) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActiveAccessCard(
                    professionalName: access.professionalName,
                    grantedAt: access.grantedAt,
                    onRevoke: () => _revokeAccess(
                      context,
                      ref,
                      accessId: access.id,
                      professionalName: access.professionalName,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const _SectionHeader(
              title: 'Autoriser un professionnel',
              subtitle: 'Professionnels disponibles dans la plateforme',
            ),
            const SizedBox(height: 10),
            if (professionalsAsync.isLoading)
              const Card(
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
                        child: Text('Chargement des professionnels...'),
                      ),
                    ],
                  ),
                ),
              )
            else if (professionalsAsync.hasError)
              const _EmptyStateCard(
                icon: Icons.error_outline,
                title: 'Chargement impossible',
                message: 'Impossible de charger la liste des professionnels.',
              )
            else if (availableProfessionals.isEmpty)
              const _EmptyStateCard(
                icon: Icons.verified_user_outlined,
                title: 'Aucun autre professionnel disponible',
                message:
                    'Tous les professionnels disponibles sont déjà autorisés ou aucun profil n’est encore disponible.',
              )
            else
              ...availableProfessionals.map(
                (professional) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProfessionalGrantCard(
                    professional: professional,
                    onGrant: () => _grantAccess(
                      context,
                      ref,
                      professional: professional,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.activeCount,
    required this.availableCount,
    required this.onOpenHistory,
  });

  final int activeCount;
  final int availableCount;
  final VoidCallback onOpenHistory;

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
              'Résumé des autorisations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniBadge(label: '$activeCount accès actif(s)'),
                _MiniBadge(
                  label: '$availableCount professionnel(s) disponible(s)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              activeCount == 0
                  ? 'Aucun accès n’est actif pour le moment.'
                  : 'Vous pouvez consulter l’historique complet des consultations et autorisations.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Voir l’historique des accès'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAccessCard extends StatelessWidget {
  const _ActiveAccessCard({
    required this.professionalName,
    required this.grantedAt,
    required this.onRevoke,
  });

  final String professionalName;
  final DateTime grantedAt;
  final VoidCallback onRevoke;

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
              professionalName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Autorisé le ${_formatDateTime(grantedAt)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _MiniBadge(label: 'Accès actif'),
                _MiniBadge(label: 'Lecture autorisée'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRevoke,
                icon: const Icon(Icons.block_outlined),
                label: const Text('Révoquer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalGrantCard extends StatelessWidget {
  const _ProfessionalGrantCard({
    required this.professional,
    required this.onGrant,
  });

  final ProfessionalProfile professional;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subtitleParts = <String>[
      if (professional.specialty.trim().isNotEmpty) professional.specialty,
      if (professional.shortLocation.trim().isNotEmpty)
        professional.shortLocation,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              professional.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' • '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _MiniBadge(label: 'Nouveau professionnel'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Autoriser cet accès'),
              ),
            ),
          ],
        ),
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
            Icon(Icons.shield_outlined, color: cs.primary),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 34, color: cs.onSurfaceVariant),
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

String _formatDateTime(DateTime value) {
  final d = value;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final mon = d.month.toString().padLeft(2, '0');
  return '$dd/$mon/${d.year} à $hh:$mm';
}