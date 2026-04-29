import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/teleconsultation_session.dart';
import '../providers/teleconsultation_providers.dart';

class TeleconsultationDetailPage extends ConsumerWidget {
  const TeleconsultationDetailPage({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  Future<void> _acceptConsent(
    BuildContext context,
    WidgetRef ref,
    TeleconsultationSession session,
  ) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Consentement téléconsultation'),
            content: const Text(
              'En acceptant, vous confirmez vouloir accéder à une téléconsultation médicale. '
              'Dans cette version MVP, la salle vidéo est simulée. En production, l’accès vidéo sera sécurisé et journalisé.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Refuser'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Accepter'),
              ),
            ],
          ),
        ) ??
        false;

    if (!accepted) return;

    await ref
        .read(teleconsultationControllerProvider)
        .acceptConsent(session.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Consentement téléconsultation accepté.'),
        ),
      );
  }

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    TeleconsultationSession session,
  ) async {
    try {
      await ref
          .read(teleconsultationControllerProvider)
          .startSession(session.id);

      if (!context.mounted) return;

      _openRoom(context, session.id);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de démarrer cette téléconsultation.',
            ),
          ),
        );
    }
  }

  Future<void> _markWaitingAndJoin(
    BuildContext context,
    WidgetRef ref,
    TeleconsultationSession session,
  ) async {
    try {
      if (session.status == TeleconsultationStatus.scheduled) {
        await ref
            .read(teleconsultationControllerProvider)
            .markWaiting(session.id);
      }

      if (!context.mounted) return;
      _openRoom(context, session.id);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de rejoindre cette téléconsultation.',
            ),
          ),
        );
    }
  }

  Future<void> _cancelSession(
    BuildContext context,
    WidgetRef ref,
    TeleconsultationSession session,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Annuler la téléconsultation'),
            content: const Text(
              'Voulez-vous vraiment annuler cette téléconsultation ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Retour'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await ref
        .read(teleconsultationControllerProvider)
        .cancelSession(session.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Téléconsultation annulée.')),
      );
  }

  void _openRoom(BuildContext context, String id) {
    Navigator.of(context).pushNamed(
      AppRoutes.teleconsultationRoom,
      arguments: TeleconsultationRoomArgs(sessionId: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedId = sessionId.trim();

    if (normalizedId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Téléconsultation'),
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

    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final sessionAsync = ref.watch(teleconsultationByIdProvider(normalizedId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Téléconsultation'),
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
                    'Cette téléconsultation n’existe pas ou n’est plus disponible.',
              );
            }

            final isProfessional = user?.role == AppUserRole.professional;
            final canJoin = session.canJoin && !session.isClosed;
            final canStart = isProfessional && session.canStart;
            final canCancel = !session.isClosed &&
                session.status != TeleconsultationStatus.inProgress;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(
                  session: session,
                  isProfessional: isProfessional,
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'Statut',
                  icon: Icons.info_outline,
                  children: [
                    _Line(label: 'État', value: _statusLabel(session.status)),
                    _Line(
                      label: 'Date',
                      value: _formatDateTime(session.scheduledAt),
                    ),
                    _Line(
                      label: 'Motif',
                      value: session.reason.trim().isEmpty
                          ? 'Non renseigné'
                          : session.reason,
                    ),
                    _Line(
                      label: 'Consentement',
                      value: session.consentAccepted
                          ? 'Accepté'
                          : 'En attente',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'Participants',
                  icon: Icons.people_outline,
                  children: [
                    _Line(label: 'Patient', value: session.patientName),
                    _Line(
                      label: 'Professionnel',
                      value: session.professionalName,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'Sécurité & confidentialité',
                  icon: Icons.shield_outlined,
                  children: const [
                    Text(
                      'Dans cette version MVP, la salle de téléconsultation est simulée. '
                      'En production, l’appel vidéo devra passer par une infrastructure sécurisée, idéalement auto-hébergée, avec rooms éphémères, accès contrôlé et journalisation.',
                    ),
                  ],
                ),
                if (!session.consentAccepted && !isProfessional) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _acceptConsent(context, ref, session),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Accepter le consentement'),
                    ),
                  ),
                ],
                if (canStart) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _startSession(context, ref, session),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Démarrer la téléconsultation'),
                    ),
                  ),
                ],
                if (!isProfessional && canJoin) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _markWaitingAndJoin(context, ref, session),
                      icon: const Icon(Icons.video_call_outlined),
                      label: const Text('Rejoindre la salle'),
                    ),
                  ),
                ],
                if (isProfessional &&
                    session.status == TeleconsultationStatus.inProgress) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _openRoom(context, session.id),
                      icon: const Icon(Icons.video_call_outlined),
                      label: const Text('Ouvrir la salle'),
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelSession(context, ref, session),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: const Text('Annuler la téléconsultation'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.session,
    required this.isProfessional,
  });

  final TeleconsultationSession session;
  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title =
        isProfessional ? session.patientName : session.professionalName;

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
                Icons.video_call_outlined,
                color: cs.onPrimaryContainer,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.trim().isEmpty
                        ? 'Téléconsultation'
                        : title.trim(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(session.scheduledAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(label: _statusLabel(session.status)),
                      if (session.consentAccepted)
                        const _Badge(label: 'Consentement accepté')
                      else
                        const _Badge(label: 'Consentement requis'),
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
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
  });

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

String _formatDateTime(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');

  return '$dd/$mm/${value.year} à $hh:$min';
}