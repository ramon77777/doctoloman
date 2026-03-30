import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/ui/info_widgets.dart';
import '../../domain/appointment.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_badges.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});

  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref
        .read(appointmentsFiltersProvider.notifier)
        .setQuery(_searchCtrl.text);
  }

  Future<void> _refresh() async {
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(appointmentsStatsProvider);
    ref.invalidate(nextUpcomingAppointmentProvider);
    ref.invalidate(filteredAppointmentsProvider);
    await ref.read(appointmentsListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final statsAsync = ref.watch(appointmentsStatsProvider);
    final filteredAsync = ref.watch(filteredAppointmentsProvider);
    final nextAppointmentAsync = ref.watch(nextUpcomingAppointmentProvider);
    final filters = ref.watch(appointmentsFiltersProvider);

    if (_searchCtrl.text != filters.query) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: filters.query,
        selection: TextSelection.collapsed(offset: filters.query.length),
        composing: TextRange.empty,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(appointmentsListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: appointmentsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateView(
                      icon: Icons.event_busy_outlined,
                      title: 'Aucun rendez-vous',
                      message:
                          'Vos demandes envoyées et vos rendez-vous confirmés apparaîtront ici.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  statsAsync.when(
                    data: (stats) => _AppointmentsStatsBar(
                      totalCount: stats.totalCount,
                      pendingCount: stats.pendingCount,
                      upcomingConfirmedCount: stats.upcomingConfirmedCount,
                      confirmedCount: stats.confirmedCount,
                      cancelledCount: stats.cancelledCount,
                    ),
                    loading: () => const _StatsBarSkeleton(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  const _ReminderInfoBanner(),
                  nextAppointmentAsync.when(
                    data: (appointment) {
                      if (appointment == null ||
                          filters.filter != AppointmentsViewFilter.all) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 14),
                          _NextAppointmentCard(appointment: appointment),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Rechercher',
                      hintText: 'Professionnel, spécialité, adresse, motif...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: filters.query.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer',
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(
                                      appointmentsFiltersProvider.notifier,
                                    )
                                    .clearQuery();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    data: (stats) => _AppointmentsFilterBar(
                      selectedFilter: filters.filter,
                      allCount: stats.totalCount,
                      pendingCount: stats.pendingCount,
                      upcomingCount: stats.upcomingConfirmedCount,
                      historyCount: stats.historyCount,
                      cancelledCount: stats.cancelledCount,
                      onSelected: (value) {
                        ref
                            .read(appointmentsFiltersProvider.notifier)
                            .setFilter(value);
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  filteredAsync.when(
                    data: (filteredItems) {
                      if (filteredItems.isEmpty) {
                        return const EmptyStateView(
                          icon: Icons.manage_search_outlined,
                          title: 'Aucun résultat',
                          message:
                              'Aucun rendez-vous ne correspond à votre recherche ou au filtre sélectionné.',
                        );
                      }

                      return Column(
                        children: filteredItems.map((appointment) {
                          final highlight =
                              filters.filter == AppointmentsViewFilter.upcoming &&
                                  AppDateFormatters.isToday(
                                    appointment.scheduledAt,
                                  );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AppointmentCard(
                              appointment: appointment,
                              highlight: highlight,
                              onTap: () => _openDetail(
                                context,
                                appointment.id,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => ErrorStateView(
                      message: '$e',
                    ),
                  ),
                ],
              ),
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

  void _openDetail(BuildContext context, String appointmentId) {
    Navigator.of(context).pushNamed(
      AppRoutes.appointmentDetail,
      arguments: AppointmentDetailArgs(
        appointmentId: appointmentId,
      ),
    );
  }
}

class _AppointmentsStatsBar extends StatelessWidget {
  const _AppointmentsStatsBar({
    required this.totalCount,
    required this.pendingCount,
    required this.upcomingConfirmedCount,
    required this.confirmedCount,
    required this.cancelledCount,
  });

  final int totalCount;
  final int pendingCount;
  final int upcomingConfirmedCount;
  final int confirmedCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatChip(label: '$totalCount rendez-vous'),
          _StatChip(label: '$pendingCount en attente'),
          _StatChip(label: '$upcomingConfirmedCount à venir'),
          _StatChip(label: '$confirmedCount confirmés'),
          _StatChip(label: '$cancelledCount clos'),
        ],
      ),
    );
  }
}

class _StatsBarSkeleton extends StatelessWidget {
  const _StatsBarSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip() => Container(
          height: 34,
          width: 120,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(),
        chip(),
        chip(),
        chip(),
      ],
    );
  }
}

class _ReminderInfoBanner extends StatelessWidget {
  const _ReminderInfoBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: cs.primary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Une demande envoyée reste en attente tant que le professionnel ne l’a pas confirmée. Les rendez-vous confirmés apparaissent séparément.',
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.schedule_outlined,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prochain rendez-vous',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${appointment.practitionerName} • ${appointment.specialty}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer,
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

class _AppointmentsFilterBar extends StatelessWidget {
  const _AppointmentsFilterBar({
    required this.selectedFilter,
    required this.allCount,
    required this.pendingCount,
    required this.upcomingCount,
    required this.historyCount,
    required this.cancelledCount,
    required this.onSelected,
  });

  final AppointmentsViewFilter selectedFilter;
  final int allCount;
  final int pendingCount;
  final int upcomingCount;
  final int historyCount;
  final int cancelledCount;
  final ValueChanged<AppointmentsViewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChipItem(
            label: 'Tous ($allCount)',
            selected: selectedFilter == AppointmentsViewFilter.all,
            onTap: () => onSelected(AppointmentsViewFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'En attente ($pendingCount)',
            selected: selectedFilter == AppointmentsViewFilter.pending,
            onTap: () => onSelected(AppointmentsViewFilter.pending),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'À venir ($upcomingCount)',
            selected: selectedFilter == AppointmentsViewFilter.upcoming,
            onTap: () => onSelected(AppointmentsViewFilter.upcoming),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Historique ($historyCount)',
            selected: selectedFilter == AppointmentsViewFilter.history,
            onTap: () => onSelected(AppointmentsViewFilter.history),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Clos ($cancelledCount)',
            selected: selectedFilter == AppointmentsViewFilter.cancelled,
            onTap: () => onSelected(AppointmentsViewFilter.cancelled),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
    this.highlight = false,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle =
        '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}\n${appointment.fullAddress}';

    return Card(
      color: highlight ? cs.primaryContainer.withValues(alpha: 0.35) : null,
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
                  Icons.event_note_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.practitionerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.specialty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        if (AppDateFormatters.isToday(appointment.scheduledAt))
                          const AppointmentMiniBadge(label: 'Aujourd’hui')
                        else if (AppDateFormatters.isTomorrow(
                          appointment.scheduledAt,
                        ))
                          const AppointmentMiniBadge(label: 'Demain'),
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