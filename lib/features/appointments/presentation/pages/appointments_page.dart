import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/ui/info_widgets.dart';
import '../../domain/appointment.dart';
import '../helpers/appointment_ui_helpers.dart';
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
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(appointmentsFiltersProvider.notifier).setQuery(_searchCtrl.text);
  }

  Future<void> _refresh() async {
    _invalidateAppointmentsQueries();
    await ref.read(appointmentsListProvider.future);
  }

  void _invalidateAppointmentsQueries() {
    ref.invalidate(allAppointmentsProvider);
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(appointmentsStatsProvider);
    ref.invalidate(nextUpcomingAppointmentProvider);
    ref.invalidate(filteredAppointmentsProvider);
  }

  void _syncSearchControllerIfNeeded(String query) {
    if (_searchCtrl.text == query) return;

    _searchCtrl.value = _searchCtrl.value.copyWith(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
      composing: TextRange.empty,
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

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final filters = ref.watch(appointmentsFiltersProvider);

    _syncSearchControllerIfNeeded(filters.query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _invalidateAppointmentsQueries,
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
                  padding: const EdgeInsets.all(16),
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

            final allSections = _AppointmentsSections.fromItems(items);
            final nextAppointment = allSections.upcoming.isNotEmpty
                ? allSections.upcoming.first
                : null;

            final filteredItems = _applyFilters(
              items: items,
              filter: filters.filter,
              query: filters.query,
            );

            final filteredSections = _AppointmentsSections.fromItems(
              filteredItems,
            );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AppointmentsStatsBar(
                    totalCount: items.length,
                    pendingCount: allSections.pending.length,
                    upcomingConfirmedCount: allSections.upcoming.length,
                    historyCount: allSections.history.length,
                    closedCount: allSections.closed.length,
                  ),
                  const SizedBox(height: 14),
                  const _ReminderInfoBanner(),
                  if (nextAppointment != null &&
                      filters.filter == AppointmentsViewFilter.all) ...[
                    const SizedBox(height: 14),
                    _NextAppointmentCard(
                      appointment: nextAppointment,
                      onTap: () => _openDetail(context, nextAppointment.id),
                    ),
                  ],
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
                                    .read(appointmentsFiltersProvider.notifier)
                                    .clearQuery();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AppointmentsFilterBar(
                    selectedFilter: filters.filter,
                    allCount: items.length,
                    pendingCount: allSections.pending.length,
                    upcomingCount: allSections.upcoming.length,
                    historyCount: allSections.history.length,
                    closedCount: allSections.closed.length,
                    onSelected: (value) {
                      ref
                          .read(appointmentsFiltersProvider.notifier)
                          .setFilter(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (filteredItems.isEmpty)
                    const EmptyStateView(
                      icon: Icons.manage_search_outlined,
                      title: 'Aucun résultat',
                      message:
                          'Aucun rendez-vous ne correspond à votre recherche ou au filtre sélectionné.',
                    )
                  else
                    _AppointmentsSectionsView(
                      sections: filteredSections,
                      selectedFilter: filters.filter,
                      onOpenDetail: (appointmentId) {
                        _openDetail(context, appointmentId);
                      },
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => ErrorStateView(
            message: '$error',
          ),
        ),
      ),
    );
  }
}

class _AppointmentsSections {
  const _AppointmentsSections({
    required this.pending,
    required this.upcoming,
    required this.history,
    required this.closed,
  });

  final List<Appointment> pending;
  final List<Appointment> upcoming;
  final List<Appointment> history;
  final List<Appointment> closed;

  factory _AppointmentsSections.fromItems(List<Appointment> items) {
    final pending = items.where(AppointmentUiHelpers.isPending).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final upcoming =
        items.where(AppointmentUiHelpers.isUpcomingConfirmed).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final history = items.where(_isPatientHistoryAppointment).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final closed = items.where(_isPatientClosedAppointment).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return _AppointmentsSections(
      pending: List<Appointment>.unmodifiable(pending),
      upcoming: List<Appointment>.unmodifiable(upcoming),
      history: List<Appointment>.unmodifiable(history),
      closed: List<Appointment>.unmodifiable(closed),
    );
  }
}

class _AppointmentsSectionsView extends StatelessWidget {
  const _AppointmentsSectionsView({
    required this.sections,
    required this.selectedFilter,
    required this.onOpenDetail,
  });

  final _AppointmentsSections sections;
  final AppointmentsViewFilter selectedFilter;
  final ValueChanged<String> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    final showAll = selectedFilter == AppointmentsViewFilter.all;

    void addSection({
      required String title,
      required String subtitle,
      required IconData icon,
      required List<Appointment> items,
    }) {
      if (items.isEmpty) return;

      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
      }

      widgets.add(
        _SectionTitle(
          title: title,
          subtitle: subtitle,
          icon: icon,
        ),
      );
      widgets.add(const SizedBox(height: 10));

      widgets.addAll(
        items.map(
          (appointment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AppointmentCard(
              appointment: appointment,
              highlight: selectedFilter == AppointmentsViewFilter.upcoming &&
                  AppDateFormatters.isToday(appointment.scheduledAt),
              onTap: () => onOpenDetail(appointment.id),
            ),
          ),
        ),
      );
    }

    addSection(
      title: 'Demandes en attente',
      subtitle:
          'Demandes envoyées au professionnel en attente de réponse',
      icon: Icons.pending_actions_outlined,
      items: showAll || selectedFilter == AppointmentsViewFilter.pending
          ? sections.pending
          : const [],
    );

    addSection(
      title: 'Rendez-vous à venir',
      subtitle: 'Rendez-vous confirmés, à venir ou prévus aujourd’hui',
      icon: Icons.event_available_outlined,
      items: showAll || selectedFilter == AppointmentsViewFilter.upcoming
          ? sections.upcoming
          : const [],
    );

    addSection(
      title: 'Historique',
      subtitle: 'Rendez-vous passés ou réalisés',
      icon: Icons.history_outlined,
      items: showAll || selectedFilter == AppointmentsViewFilter.history
          ? sections.history
          : const [],
    );

    addSection(
      title: 'Clôturés',
      subtitle:
          'Demandes refusées, rendez-vous annulés ou absences signalées',
      icon: Icons.event_busy_outlined,
      items: showAll || selectedFilter == AppointmentsViewFilter.cancelled
          ? sections.closed
          : const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

class _AppointmentsStatsBar extends StatelessWidget {
  const _AppointmentsStatsBar({
    required this.totalCount,
    required this.pendingCount,
    required this.upcomingConfirmedCount,
    required this.historyCount,
    required this.closedCount,
  });

  final int totalCount;
  final int pendingCount;
  final int upcomingConfirmedCount;
  final int historyCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatChip(label: '$totalCount total'),
          _StatChip(label: '$pendingCount en attente'),
          _StatChip(label: '$upcomingConfirmedCount à venir'),
          _StatChip(label: '$historyCount historique'),
          _StatChip(label: '$closedCount clos'),
        ],
      ),
    );
  }
}

class _ReminderInfoBanner extends StatelessWidget {
  const _ReminderInfoBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.primary,
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
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prochain rendez-vous',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appointment.practitionerName} • ${appointment.specialty}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
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
    required this.closedCount,
    required this.onSelected,
  });

  final AppointmentsViewFilter selectedFilter;
  final int allCount;
  final int pendingCount;
  final int upcomingCount;
  final int historyCount;
  final int closedCount;
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
            label: 'Clos ($closedCount)',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle =
        '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}\n${appointment.fullAddress}';

    return Card(
      color: highlight
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_note_outlined,
                  color: colorScheme.primary,
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
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appointment.reason,
                      style: Theme.of(context).textTheme.bodyMedium,
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
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Appointment> _applyFilters({
  required List<Appointment> items,
  required AppointmentsViewFilter filter,
  required String query,
}) {
  final normalizedQuery = _normalizeSearch(query);

  final filteredByQuery = items.where((appointment) {
    if (normalizedQuery.isEmpty) return true;

    final haystack = _normalizeSearch(
      '${appointment.practitionerName} '
      '${appointment.specialty} '
      '${appointment.fullAddress} '
      '${appointment.reason} '
      '${appointment.slot}',
    );

    return haystack.contains(normalizedQuery);
  });

  final filteredByStatus = filteredByQuery.where((appointment) {
    switch (filter) {
      case AppointmentsViewFilter.all:
        return true;
      case AppointmentsViewFilter.pending:
        return AppointmentUiHelpers.isPending(appointment);
      case AppointmentsViewFilter.upcoming:
        return AppointmentUiHelpers.isUpcomingConfirmed(appointment);
      case AppointmentsViewFilter.history:
        return _isPatientHistoryAppointment(appointment);
      case AppointmentsViewFilter.cancelled:
        return _isPatientClosedAppointment(appointment);
    }
  }).toList();

  filteredByStatus.sort(
    (a, b) {
      if (filter == AppointmentsViewFilter.history ||
          filter == AppointmentsViewFilter.cancelled) {
        return b.scheduledAt.compareTo(a.scheduledAt);
      }

      return a.scheduledAt.compareTo(b.scheduledAt);
    },
  );

  return filteredByStatus;
}

bool _isPatientHistoryAppointment(Appointment appointment) {
  return AppointmentUiHelpers.isHistory(appointment) ||
      appointment.status == AppointmentStatus.completed;
}

bool _isPatientClosedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.cancelledByPatient ||
      appointment.status == AppointmentStatus.cancelledByProfessional ||
      appointment.status == AppointmentStatus.declinedByProfessional ||
      appointment.status == AppointmentStatus.noShow;
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}