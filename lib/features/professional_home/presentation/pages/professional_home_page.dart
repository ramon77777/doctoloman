import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/models/app_user.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../../professional_schedule/presentation/providers/professional_schedule_providers.dart';

@immutable
class _ProfessionalHomeData {
  const _ProfessionalHomeData({
    required this.all,
    required this.pending,
    required this.confirmedUpcoming,
    required this.todayConfirmed,
    required this.closed,
  });

  final List<Appointment> all;
  final List<Appointment> pending;
  final List<Appointment> confirmedUpcoming;
  final List<Appointment> todayConfirmed;
  final List<Appointment> closed;
}

class ProfessionalHomePage extends ConsumerWidget {
  const ProfessionalHomePage({super.key});

  Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref, {
    required Appointment appointment,
    required AppointmentStatus newStatus,
    required String title,
    required String message,
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
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    await ref.read(appointmentsControllerProvider).updateStatus(
          id: appointment.id,
          status: newStatus,
        );

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(allAppointmentsProvider);
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(appointmentsStatsProvider);
    ref.invalidate(nextUpcomingAppointmentProvider);
    ref.invalidate(filteredAppointmentsProvider);
    await ref.read(appointmentsListProvider.future);
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Se déconnecter'),
            content: const Text(
              'Voulez-vous vraiment vous déconnecter de l’espace professionnel ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Déconnexion'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await ref.read(authControllerProvider.notifier).logout();

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Vous êtes déconnecté.'),
        ),
      );
  }

  Future<void> _openSessionMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Profil professionnel'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed(
                      AppRoutes.professionalProfile,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Mes disponibilités'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed(
                      AppRoutes.professionalSchedule,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Se déconnecter'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleLogout(context, ref);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final profile = ref.watch(professionalProfileProvider);
    final schedule = ref.watch(practitionerScheduleProvider(profile.id));

    final openDaysCount = schedule.where((day) => day.isOpen).length;

    if (!authState.isAuthenticated || !authState.isProfessional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Espace professionnel'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté avec un compte professionnel pour accéder à cet espace.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace professionnel'),
        actions: [
          IconButton(
            tooltip: 'Profil professionnel',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.professionalProfile);
            },
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            tooltip: 'Session',
            onPressed: () => _openSessionMenu(context, ref),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WelcomeHeader(profile: profile),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$openDaysCount jour(s) d’ouverture configurés',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalSchedule,
                          );
                        },
                        child: const Text('Horaires'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              appointmentsAsync.when(
                data: (items) {
                  final data = _buildHomeData(
                    items: items,
                    profile: profile,
                    authUser: authState.user,
                  );

                  final nextPending =
                      data.pending.isNotEmpty ? data.pending.first : null;
                  final nextToday =
                      data.todayConfirmed.isNotEmpty
                          ? data.todayConfirmed.first
                          : null;

                  return Column(
                    children: [
                      _StatsGrid(
                        pendingCount: data.pending.length,
                        confirmedCount: data.confirmedUpcoming.length,
                        todayCount: data.todayConfirmed.length,
                        totalCount: data.all.length,
                      ),
                      const SizedBox(height: 16),
                      _QuickActionsCard(
                        onOpenAppointments: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalAppointments,
                          );
                        },
                        onOpenProfile: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalProfile,
                          );
                        },
                        onOpenSchedule: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalSchedule,
                          );
                        },
                      ),
                      if (nextPending != null || nextToday != null) ...[
                        const SizedBox(height: 16),
                        _PriorityCard(
                          nextPending: nextPending,
                          nextToday: nextToday,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PendingRequestsCard(
                        items: data.pending.take(5).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalAppointments,
                          );
                        },
                        onConfirm: (appointment) => _confirmStatusChange(
                          context,
                          ref,
                          appointment: appointment,
                          newStatus: AppointmentStatus.confirmed,
                          title: 'Confirmer le rendez-vous',
                          message:
                              'Souhaitez-vous confirmer ce rendez-vous pour ${appointment.patientFullName} ?',
                          successMessage: 'Rendez-vous confirmé.',
                        ),
                        onRefuse: (appointment) => _confirmStatusChange(
                          context,
                          ref,
                          appointment: appointment,
                          newStatus:
                              AppointmentStatus.declinedByProfessional,
                          title: 'Refuser la demande',
                          message:
                              'Souhaitez-vous refuser cette demande pour ${appointment.patientFullName} ?',
                          successMessage: 'Demande refusée.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TodayAgendaCard(
                        items: data.todayConfirmed.take(5).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalAppointments,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _UpcomingAppointmentsCard(
                        items: data.confirmedUpcoming.take(5).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.professionalAppointments,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ActivitySummaryCard(
                        confirmedUpcomingCount: data.confirmedUpcoming.length,
                        closedCount: data.closed.length,
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Impossible de charger les rendez-vous : $error',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_ProfessionalHomeData _buildHomeData({
  required List<Appointment> items,
  required ProfessionalProfile profile,
  required AppUser? authUser,
}) {
  final professionalItems = items.where((item) {
    return _belongsToProfessional(
      appointment: item,
      profile: profile,
      authUser: authUser,
    );
  }).toList();

  final pending = professionalItems
      .where((item) => item.status == AppointmentStatus.pending)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final confirmedUpcoming = professionalItems
      .where(
        (item) =>
            item.status == AppointmentStatus.confirmed && item.isUpcoming,
      )
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final todayConfirmed = professionalItems
      .where(
        (item) =>
            item.status == AppointmentStatus.confirmed &&
            AppDateFormatters.isToday(item.scheduledAt),
      )
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final closed = professionalItems
      .where((item) => item.isCancelledLike)
      .toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  return _ProfessionalHomeData(
    all: List<Appointment>.unmodifiable(professionalItems),
    pending: List<Appointment>.unmodifiable(pending),
    confirmedUpcoming: List<Appointment>.unmodifiable(confirmedUpcoming),
    todayConfirmed: List<Appointment>.unmodifiable(todayConfirmed),
    closed: List<Appointment>.unmodifiable(closed),
  );
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.profile,
  });

  final ProfessionalProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final subtitleParts = <String>[
      if (profile.specialty.trim().isNotEmpty) profile.specialty.trim(),
      if (profile.structureName.trim().isNotEmpty) profile.structureName.trim(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour ${profile.displayName}',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          subtitleParts.isEmpty
              ? 'Professionnel de santé'
              : subtitleParts.join(' • '),
          style: textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.pendingCount,
    required this.confirmedCount,
    required this.todayCount,
    required this.totalCount,
  });

  final int pendingCount;
  final int confirmedCount;
  final int todayCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        _StatCard(
          icon: Icons.pending_actions_outlined,
          title: 'En attente',
          value: '$pendingCount',
        ),
        _StatCard(
          icon: Icons.event_available_outlined,
          title: 'Confirmés',
          value: '$confirmedCount',
        ),
        _StatCard(
          icon: Icons.today_outlined,
          title: 'Aujourd’hui',
          value: '$todayCount',
        ),
        _StatCard(
          icon: Icons.list_alt_outlined,
          title: 'Total',
          value: '$totalCount',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 10),
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onOpenAppointments,
    required this.onOpenProfile,
    required this.onOpenSchedule,
  });

  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.medical_information_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ouvrir la gestion des rendez-vous professionnels',
                  ),
                ),
                FilledButton(
                  onPressed: onOpenAppointments,
                  child: const Text('Ouvrir'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Consulter et préparer le profil professionnel',
                  ),
                ),
                OutlinedButton(
                  onPressed: onOpenProfile,
                  child: const Text('Profil'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Configurer les jours et horaires de consultation',
                  ),
                ),
                OutlinedButton(
                  onPressed: onOpenSchedule,
                  child: const Text('Créneaux'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    this.nextPending,
    this.nextToday,
  });

  final Appointment? nextPending;
  final Appointment? nextToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Priorités',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            if (nextPending != null)
              Text(
                '• Demande à traiter : ${nextPending!.patientFullName} • ${nextPending!.reason} • ${nextPending!.slot}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
              ),
            if (nextToday != null)
              Padding(
                padding: EdgeInsets.only(top: nextPending != null ? 6 : 0),
                child: Text(
                  '• Prochain rendez-vous du jour : ${nextToday!.patientFullName} • ${nextToday!.reason} • ${nextToday!.slot}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsCard extends StatelessWidget {
  const _PendingRequestsCard({
    required this.items,
    required this.onOpenAll,
    required this.onConfirm,
    required this.onRefuse,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;
  final ValueChanged<Appointment> onConfirm;
  final ValueChanged<Appointment> onRefuse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demandes en attente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'Aucune demande en attente pour le moment.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.hourglass_top_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.slot} • ${item.patientFullName} • ${item.reason}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 360;

                          if (compact) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => onConfirm(item),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Confirmer'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => onRefuse(item),
                                    icon: const Icon(Icons.event_busy_outlined),
                                    label: const Text('Refuser'),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => onConfirm(item),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Confirmer'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => onRefuse(item),
                                  icon: const Icon(Icons.event_busy_outlined),
                                  label: const Text('Refuser'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenAll,
              child: const Text('Voir toutes les demandes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayAgendaCard extends StatelessWidget {
  const _TodayAgendaCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agenda du jour',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'Aucun rendez-vous confirmé aujourd’hui.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.slot} • ${item.patientFullName} • ${item.reason}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenAll,
              child: const Text('Voir tout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentsCard extends StatelessWidget {
  const _UpcomingAppointmentsCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final upcomingWithoutToday = items
        .where((item) => !AppDateFormatters.isToday(item.scheduledAt))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'À venir',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (upcomingWithoutToday.isEmpty)
              Text(
                'Aucun autre rendez-vous confirmé à venir.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              )
            else
              ...upcomingWithoutToday.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${AppDateFormatters.formatShortDate(item.day)} • ${item.slot} • ${item.patientFullName}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenAll,
              child: const Text('Voir tout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.confirmedUpcomingCount,
    required this.closedCount,
  });

  final int confirmedUpcomingCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé d’activité',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$confirmedUpcomingCount rendez-vous confirmé(s) à venir • $closedCount dossier(s) clos',
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

bool _belongsToProfessional({
  required Appointment appointment,
  required ProfessionalProfile profile,
  required AppUser? authUser,
}) {
  final appointmentPractitionerId = _normalizeKey(appointment.practitionerId);
  final appointmentPractitionerName =
      _normalizeSearch(appointment.practitionerName);

  final profileId = _normalizeKey(profile.id);
  final profileName = _normalizeSearch(profile.displayName);

  final authId = _normalizeKey(authUser?.id ?? '');
  final authName = _normalizeSearch(authUser?.name ?? '');

  final byProfileId =
      profileId.isNotEmpty && appointmentPractitionerId == profileId;
  final byProfileName =
      profileName.isNotEmpty && appointmentPractitionerName == profileName;
  final byAuthId = authId.isNotEmpty && appointmentPractitionerId == authId;
  final byAuthName =
      authName.isNotEmpty && appointmentPractitionerName == authName;

  return byProfileId || byProfileName || byAuthId || byAuthName;
}

String _normalizeKey(String value) {
  return value.trim();
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll("’", "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}