import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/teleconsultation_session.dart';
import '../providers/teleconsultation_providers.dart';

class TeleconsultationRoomPage extends ConsumerWidget {
  const TeleconsultationRoomPage({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  Future<void> _endSession(
    BuildContext context,
    WidgetRef ref,
    TeleconsultationSession session,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Terminer la téléconsultation'),
            content: const Text(
              'Voulez-vous terminer cette téléconsultation ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Retour'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Terminer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ref
          .read(teleconsultationControllerProvider)
          .endSession(session.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Téléconsultation terminée.'),
          ),
        );

      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de terminer cette téléconsultation.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedId = sessionId.trim();

    if (normalizedId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Salle de téléconsultation'),
        ),
        body: const SafeArea(
          child: _MessageState(
            icon: Icons.search_off_outlined,
            title: 'Session introuvable',
            message: 'Aucun identifiant de téléconsultation valide.',
          ),
        ),
      );
    }

    final authUser = ref.watch(authControllerProvider).user;
    final sessionAsync = ref.watch(teleconsultationByIdProvider(normalizedId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salle de téléconsultation'),
      ),
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MessageState(
            icon: Icons.error_outline,
            title: 'Erreur',
            message: '$error',
          ),
          data: (session) {
            if (session == null) {
              return const _MessageState(
                icon: Icons.search_off_outlined,
                title: 'Session introuvable',
                message:
                    'Cette salle de téléconsultation n’existe pas ou n’est plus disponible.',
              );
            }

            final isProfessional =
                authUser?.role == AppUserRole.professional;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RoomMockCard(session: session),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'Session',
                  icon: Icons.info_outline,
                  children: [
                    _Line(label: 'État', value: _statusLabel(session.status)),
                    _Line(label: 'Patient', value: session.patientName),
                    _Line(
                      label: 'Professionnel',
                      value: session.professionalName,
                    ),
                    _Line(label: 'Motif', value: session.reason),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'Intégration vidéo',
                  icon: Icons.integration_instructions_outlined,
                  children: [
                    Text(
                      'Cette salle est une simulation MVP. L’intégration vidéo réelle devra utiliser une room éphémère sécurisée générée côté backend.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Room mock : ${session.safeRoomUrl}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                if (isProfessional &&
                    session.status == TeleconsultationStatus.inProgress) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _endSession(context, ref, session),
                      icon: const Icon(Icons.call_end_outlined),
                      label: const Text('Terminer la téléconsultation'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomMockCard extends StatelessWidget {
  const _RoomMockCard({
    required this.session,
  });

  final TeleconsultationSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.video_call_outlined,
              size: 54,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              'Salle de téléconsultation sécurisée',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Simulation MVP — l’appel vidéo réel sera intégré ultérieurement.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _RoomBadge(
                  label: _statusLabel(session.status),
                  foreground: cs.onPrimaryContainer,
                ),
                if (session.consentAccepted)
                  _RoomBadge(
                    label: 'Consentement accepté',
                    foreground: cs.onPrimaryContainer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({
    required this.label,
    required this.foreground,
  });

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Non renseigné' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
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

String _statusLabel(TeleconsultationStatus status) {
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