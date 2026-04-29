import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/teleconsultation_session.dart';
import '../providers/teleconsultation_providers.dart';

class TeleconsultationsPage extends ConsumerWidget {
  const TeleconsultationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Téléconsultations'),
        ),
        body: const SafeArea(
          child: _MessageState(
            icon: Icons.lock_outline,
            title: 'Connexion requise',
            message:
                'Vous devez être connecté pour accéder aux téléconsultations.',
          ),
        ),
      );
    }

    final isProfessional = user.role == AppUserRole.professional;
    final sessionsAsync = isProfessional
        ? ref.watch(professionalTeleconsultationsProvider)
        : ref.watch(patientTeleconsultationsProvider);

    Future<void> refresh() async {
      ref.invalidate(teleconsultationsListProvider);
      ref.invalidate(patientTeleconsultationsProvider);
      ref.invalidate(professionalTeleconsultationsProvider);

      if (isProfessional) {
        await ref.read(professionalTeleconsultationsProvider.future);
      } else {
        await ref.read(patientTeleconsultationsProvider.future);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isProfessional
              ? 'Téléconsultations pro'
              : 'Mes téléconsultations',
        ),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () {
              ref.invalidate(teleconsultationsListProvider);
              ref.invalidate(patientTeleconsultationsProvider);
              ref.invalidate(professionalTeleconsultationsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _ErrorState(
            message: '$error',
            onRetry: () {
              ref.invalidate(teleconsultationsListProvider);
              ref.invalidate(patientTeleconsultationsProvider);
              ref.invalidate(professionalTeleconsultationsProvider);
            },
          ),
          data: (sessions) {
            final sorted = [...sessions]
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

            final active = sorted.where((item) {
              return item.status == TeleconsultationStatus.scheduled ||
                  item.status == TeleconsultationStatus.waiting ||
                  item.status == TeleconsultationStatus.inProgress;
            }).toList();

            final completed = sorted.where((item) {
              return item.status == TeleconsultationStatus.completed;
            }).toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

            final cancelled = sorted.where((item) {
              return item.status == TeleconsultationStatus.cancelled;
            }).toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _IntroCard(isProfessional: isProfessional),
                  const SizedBox(height: 14),
                  _SummaryCard(
                    totalCount: sorted.length,
                    activeCount: active.length,
                    completedCount: completed.length,
                    cancelledCount: cancelled.length,
                  ),
                  const SizedBox(height: 18),
                  if (sorted.isEmpty)
                    _EmptyTeleconsultationsState(
                      isProfessional: isProfessional,
                    )
                  else ...[
                    if (active.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'À venir / en cours',
                        subtitle:
                            'Sessions programmées, en attente ou en cours',
                        icon: Icons.video_call_outlined,
                      ),
                      const SizedBox(height: 10),
                      ...active.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TeleconsultationCard(
                            session: session,
                            isProfessional: isProfessional,
                            onTap: () => _openDetail(context, session.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (completed.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'Terminées',
                        subtitle: 'Téléconsultations clôturées',
                        icon: Icons.task_alt_outlined,
                      ),
                      const SizedBox(height: 10),
                      ...completed.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TeleconsultationCard(
                            session: session,
                            isProfessional: isProfessional,
                            onTap: () => _openDetail(context, session.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (cancelled.isNotEmpty) ...[
                      const _SectionTitle(
                        title: 'Annulées',
                        subtitle: 'Sessions annulées',
                        icon: Icons.event_busy_outlined,
                      ),
                      const SizedBox(height: 10),
                      ...cancelled.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TeleconsultationCard(
                            session: session,
                            isProfessional: isProfessional,
                            onTap: () => _openDetail(context, session.id),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String sessionId) {
    Navigator.of(context).pushNamed(
      AppRoutes.teleconsultationDetail,
      arguments: TeleconsultationDetailArgs(sessionId: sessionId),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.isProfessional,
  });

  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final text = isProfessional
        ? 'Retrouvez ici vos sessions de téléconsultation créées à partir des rendez-vous confirmés. Dans cette version MVP, la salle vidéo est simulée.'
        : 'Retrouvez ici vos téléconsultations liées à vos rendez-vous confirmés. Le consentement est demandé avant l’accès à la salle.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.video_call_outlined, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
    required this.activeCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  final int totalCount;
  final int activeCount;
  final int completedCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: '$totalCount session(s)'),
            _Badge(label: '$activeCount active(s)'),
            _Badge(label: '$completedCount terminée(s)'),
            _Badge(label: '$cancelledCount annulée(s)'),
          ],
        ),
      ),
    );
  }
}

class _TeleconsultationCard extends StatelessWidget {
  const _TeleconsultationCard({
    required this.session,
    required this.isProfessional,
    required this.onTap,
  });

  final TeleconsultationSession session;
  final bool isProfessional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final personLabel =
        isProfessional ? session.patientName : session.professionalName;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                child: Icon(
                  Icons.videocam_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personLabel.trim().isEmpty
                          ? 'Participant non renseigné'
                          : personLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.reason.trim().isEmpty
                          ? 'Motif non renseigné'
                          : session.reason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(session.scheduledAt),
                      style: Theme.of(context).textTheme.bodyMedium,
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _Badge extends StatelessWidget {
  const _Badge({
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

class _EmptyTeleconsultationsState extends StatelessWidget {
  const _EmptyTeleconsultationsState({
    required this.isProfessional,
  });

  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final message = isProfessional
        ? 'Aucune téléconsultation n’est encore associée à vos rendez-vous confirmés.'
        : 'Aucune téléconsultation n’est encore associée à vos rendez-vous confirmés.';

    return _MessageCard(
      icon: Icons.video_call_outlined,
      title: 'Aucune téléconsultation',
      message: message,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 42, color: cs.onSurfaceVariant),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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