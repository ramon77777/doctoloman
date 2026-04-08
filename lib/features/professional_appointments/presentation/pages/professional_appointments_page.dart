import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/ui/info_widgets.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../appointments/presentation/widgets/appointment_badges.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';

enum _ProfessionalAppointmentsFilter {
  all,
  today,
  pending,
  upcoming,
  past,
  closed,
}

@immutable
class _ProfessionalAppointmentsSections {
  const _ProfessionalAppointmentsSections({
    required this.all,
    required this.today,
    required this.pending,
    required this.upcomingConfirmed,
    required this.pastConfirmed,
    required this.declined,
    required this.patientCancelled,
    required this.closed,
  });

  final List<Appointment> all;
  final List<Appointment> today;
  final List<Appointment> pending;
  final List<Appointment> upcomingConfirmed;
  final List<Appointment> pastConfirmed;
  final List<Appointment> declined;
  final List<Appointment> patientCancelled;
  final List<Appointment> closed;
}

class ProfessionalAppointmentsPage extends ConsumerStatefulWidget {
  const ProfessionalAppointmentsPage({super.key});

  @override
  ConsumerState<ProfessionalAppointmentsPage> createState() =>
      _ProfessionalAppointmentsPageState();
}

class _ProfessionalAppointmentsPageState
    extends ConsumerState<ProfessionalAppointmentsPage> {
  late final TextEditingController _searchCtrl;
  _ProfessionalAppointmentsFilter _selectedFilter =
      _ProfessionalAppointmentsFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController()..addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(allAppointmentsProvider);
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(appointmentsStatsProvider);
    ref.invalidate(nextUpcomingAppointmentProvider);
    ref.invalidate(filteredAppointmentsProvider);
    await ref.read(appointmentsListProvider.future);
  }

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final profile = ref.watch(professionalProfileProvider);
    final query = _normalizeSearch(_searchCtrl.text);

    if (!authState.isAuthenticated || !authState.isProfessional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rendez-vous professionnels'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté avec un compte professionnel pour accéder à cette page.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendez-vous professionnels'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: appointmentsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => ErrorStateView(
            message: 'Impossible de charger les rendez-vous : $error',
            onRetry: () => _refresh(ref),
          ),
          data: (items) {
            final professionalItems = items
                .where(
                  (item) => _belongsToProfessional(
                    appointment: item,
                    profile: profile,
                    authUser: authState.user,
                  ),
                )
                .where((item) => _matchesQuery(item, query))
                .toList();

            final sections = _buildSectionsData(professionalItems);
            final currentItems = _itemsForSelectedFilter(
              filter: _selectedFilter,
              sections: sections,
            );

            final nextPending =
                sections.pending.isNotEmpty ? sections.pending.first : null;
            final nextToday =
                sections.today.isNotEmpty ? sections.today.first : null;

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatsBar(
                    totalCount: sections.all.length,
                    todayCount: sections.today.length,
                    pendingCount: sections.pending.length,
                    confirmedCount: sections.upcomingConfirmed.length,
                    closedCount: sections.closed.length,
                  ),
                  const SizedBox(height: 14),
                  _SummaryBanner(
                    pendingCount: sections.pending.length,
                    todayCount: sections.today.length,
                  ),
                  if (_selectedFilter == _ProfessionalAppointmentsFilter.all &&
                      (nextPending != null || nextToday != null)) ...[
                    const SizedBox(height: 14),
                    _PrioritySnapshotCard(
                      nextPending: nextPending,
                      nextToday: nextToday,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Rechercher',
                      hintText: 'Patient, téléphone, motif...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer',
                              onPressed: _searchCtrl.clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FilterChipsBar(
                    selected: _selectedFilter,
                    allCount: sections.all.length,
                    todayCount: sections.today.length,
                    pendingCount: sections.pending.length,
                    upcomingCount: sections.upcomingConfirmed.length,
                    pastCount: sections.pastConfirmed.length,
                    closedCount: sections.closed.length,
                    onSelected: (value) {
                      setState(() => _selectedFilter = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (currentItems.isEmpty)
                    const EmptyStateView(
                      icon: Icons.manage_search_outlined,
                      title: 'Aucun résultat',
                      message:
                          'Aucun rendez-vous ne correspond à votre recherche ou au filtre sélectionné.',
                    )
                  else
                    ..._buildSections(
                      context,
                      ref,
                      sections: sections,
                      selectedFilter: _selectedFilter,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _ProfessionalAppointmentsSections _buildSectionsData(
    List<Appointment> items,
  ) {
    final all = [...items]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final today = all.where(_isTodayConfirmedAppointment).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final pending = all.where(_isPendingAppointment).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final upcomingConfirmed = all.where(_isUpcomingConfirmedAppointment).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final pastConfirmed = all.where(_isPastConfirmedAppointment).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final declined = all.where(_isDeclinedAppointment).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final patientCancelled = all.where(_isPatientCancelledAppointment).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final closed = <Appointment>[
      ...declined,
      ...patientCancelled,
    ]..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return _ProfessionalAppointmentsSections(
      all: List<Appointment>.unmodifiable(all),
      today: List<Appointment>.unmodifiable(today),
      pending: List<Appointment>.unmodifiable(pending),
      upcomingConfirmed: List<Appointment>.unmodifiable(upcomingConfirmed),
      pastConfirmed: List<Appointment>.unmodifiable(pastConfirmed),
      declined: List<Appointment>.unmodifiable(declined),
      patientCancelled: List<Appointment>.unmodifiable(patientCancelled),
      closed: List<Appointment>.unmodifiable(closed),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    WidgetRef ref, {
    required _ProfessionalAppointmentsSections sections,
    required _ProfessionalAppointmentsFilter selectedFilter,
  }) {
    final widgets = <Widget>[];
    final showAll = selectedFilter == _ProfessionalAppointmentsFilter.all;

    void addSection({
      required bool visible,
      required String title,
      required String subtitle,
      required IconData icon,
      required List<Appointment> items,
      required _AppointmentCardEmphasis emphasis,
      bool withPendingActions = false,
    }) {
      if (!visible || items.isEmpty) return;

      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
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
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProAppointmentCard(
              appointment: item,
              emphasis: emphasis,
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.professionalAppointmentDetail,
                  arguments: ProfessionalAppointmentDetailArgs(
                    appointmentId: item.id,
                  ),
                );
              },
              actions: withPendingActions
                  ? _PendingCardActions(
                      onConfirm: () => _confirmStatusChange(
                        context,
                        ref,
                        appointment: item,
                        newStatus: AppointmentStatus.confirmed,
                        title: 'Confirmer le rendez-vous',
                        message:
                            'Souhaitez-vous confirmer ce rendez-vous pour ${item.patientFullName} ?',
                        successMessage: 'Rendez-vous confirmé.',
                      ),
                      onRefuse: () => _confirmStatusChange(
                        context,
                        ref,
                        appointment: item,
                        newStatus: AppointmentStatus.declinedByProfessional,
                        title: 'Refuser la demande',
                        message:
                            'Souhaitez-vous refuser cette demande pour ${item.patientFullName} ?',
                        successMessage: 'Demande refusée.',
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    addSection(
      visible:
          showAll || selectedFilter == _ProfessionalAppointmentsFilter.today,
      title: 'Aujourd’hui',
      subtitle: 'Vos consultations confirmées du jour',
      icon: Icons.today_outlined,
      items: sections.today,
      emphasis: _AppointmentCardEmphasis.today,
    );

    addSection(
      visible:
          showAll || selectedFilter == _ProfessionalAppointmentsFilter.pending,
      title: 'Demandes en attente',
      subtitle: 'À confirmer ou refuser',
      icon: Icons.pending_actions_outlined,
      items: sections.pending,
      emphasis: _AppointmentCardEmphasis.pending,
      withPendingActions: true,
    );

    addSection(
      visible:
          showAll || selectedFilter == _ProfessionalAppointmentsFilter.upcoming,
      title: 'À venir',
      subtitle: 'Rendez-vous confirmés à venir',
      icon: Icons.event_available_outlined,
      items: sections.upcomingConfirmed,
      emphasis: _AppointmentCardEmphasis.upcoming,
    );

    addSection(
      visible: showAll || selectedFilter == _ProfessionalAppointmentsFilter.past,
      title: 'Passés',
      subtitle: 'Historique des rendez-vous confirmés',
      icon: Icons.history_outlined,
      items: sections.pastConfirmed,
      emphasis: _AppointmentCardEmphasis.past,
    );

    addSection(
      visible:
          showAll || selectedFilter == _ProfessionalAppointmentsFilter.closed,
      title: 'Demandes refusées',
      subtitle: 'Demandes non retenues par le professionnel',
      icon: Icons.block_outlined,
      items: sections.declined,
      emphasis: _AppointmentCardEmphasis.cancelled,
    );

    addSection(
      visible:
          showAll || selectedFilter == _ProfessionalAppointmentsFilter.closed,
      title: 'Annulés par les patients',
      subtitle: 'Demandes ou rendez-vous annulés côté patient',
      icon: Icons.event_busy_outlined,
      items: sections.patientCancelled,
      emphasis: _AppointmentCardEmphasis.cancelled,
    );

    return widgets;
  }

  List<Appointment> _itemsForSelectedFilter({
    required _ProfessionalAppointmentsFilter filter,
    required _ProfessionalAppointmentsSections sections,
  }) {
    switch (filter) {
      case _ProfessionalAppointmentsFilter.all:
        return sections.all;
      case _ProfessionalAppointmentsFilter.today:
        return sections.today;
      case _ProfessionalAppointmentsFilter.pending:
        return sections.pending;
      case _ProfessionalAppointmentsFilter.upcoming:
        return sections.upcomingConfirmed;
      case _ProfessionalAppointmentsFilter.past:
        return sections.pastConfirmed;
      case _ProfessionalAppointmentsFilter.closed:
        return sections.closed;
    }
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.totalCount,
    required this.todayCount,
    required this.pendingCount,
    required this.confirmedCount,
    required this.closedCount,
  });

  final int totalCount;
  final int todayCount;
  final int pendingCount;
  final int confirmedCount;
  final int closedCount;

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
          _ChipLabel(label: '$totalCount total'),
          _ChipLabel(label: '$todayCount aujourd’hui'),
          _ChipLabel(label: '$pendingCount en attente'),
          _ChipLabel(label: '$confirmedCount à venir'),
          _ChipLabel(label: '$closedCount clos'),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.pendingCount,
    required this.todayCount,
  });

  final int pendingCount;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final text = pendingCount > 0
        ? 'Vous avez $pendingCount demande(s) à traiter${todayCount > 0 ? ' et $todayCount rendez-vous confirmé(s) aujourd’hui.' : '.'}'
        : todayCount > 0
            ? 'Aucune demande en attente. Vous avez $todayCount rendez-vous confirmé(s) aujourd’hui.'
            : 'Aucune demande en attente pour le moment.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insights_outlined, color: cs.primary),
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

class _PrioritySnapshotCard extends StatelessWidget {
  const _PrioritySnapshotCard({
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
        padding: const EdgeInsets.all(14),
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
                '• Prochaine demande à traiter : ${nextPending!.patientFullName} • ${nextPending!.slot}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
              ),
            if (nextToday != null)
              Padding(
                padding: EdgeInsets.only(top: nextPending != null ? 6 : 0),
                child: Text(
                  '• Prochain rendez-vous du jour : ${nextToday!.patientFullName} • ${nextToday!.slot}',
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

class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({
    required this.selected,
    required this.allCount,
    required this.todayCount,
    required this.pendingCount,
    required this.upcomingCount,
    required this.pastCount,
    required this.closedCount,
    required this.onSelected,
  });

  final _ProfessionalAppointmentsFilter selected;
  final int allCount;
  final int todayCount;
  final int pendingCount;
  final int upcomingCount;
  final int pastCount;
  final int closedCount;
  final ValueChanged<_ProfessionalAppointmentsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChipItem(
            label: 'Tous ($allCount)',
            selected: selected == _ProfessionalAppointmentsFilter.all,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Aujourd’hui ($todayCount)',
            selected: selected == _ProfessionalAppointmentsFilter.today,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.today),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'En attente ($pendingCount)',
            selected: selected == _ProfessionalAppointmentsFilter.pending,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.pending),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'À venir ($upcomingCount)',
            selected: selected == _ProfessionalAppointmentsFilter.upcoming,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.upcoming),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Passés ($pastCount)',
            selected: selected == _ProfessionalAppointmentsFilter.past,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.past),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Clos ($closedCount)',
            selected: selected == _ProfessionalAppointmentsFilter.closed,
            onTap: () => onSelected(_ProfessionalAppointmentsFilter.closed),
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

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

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
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
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

enum _AppointmentCardEmphasis {
  today,
  pending,
  upcoming,
  past,
  cancelled,
}

class _PendingCardActions extends StatelessWidget {
  const _PendingCardActions({
    required this.onConfirm,
    required this.onRefuse,
  });

  final VoidCallback onConfirm;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          if (compact) {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmer'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRefuse,
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
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefuse,
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Refuser'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProAppointmentCard extends StatelessWidget {
  const _ProAppointmentCard({
    required this.appointment,
    required this.onTap,
    required this.emphasis,
    this.actions,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final _AppointmentCardEmphasis emphasis;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle =
        '${appointment.reason} • ${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}';

    return Card(
      color: emphasis == _AppointmentCardEmphasis.today
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                child: Icon(Icons.people_outline, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientFullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.patientPhoneE164,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppointmentStatusBadge(
                          status: appointment.status,
                          isProfessional: true,
                        ),
                        AppointmentTemporalBadge(
                          appointment: appointment,
                          isProfessional: true,
                        ),
                        _EmphasisBadge(emphasis: emphasis),
                        if (AppDateFormatters.isToday(appointment.scheduledAt))
                          const AppointmentMiniBadge(label: 'Aujourd’hui')
                        else if (AppDateFormatters.isTomorrow(
                          appointment.scheduledAt,
                        ))
                          const AppointmentMiniBadge(label: 'Demain'),
                      ],
                    ),
                    if (actions != null) actions!,
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

class _EmphasisBadge extends StatelessWidget {
  const _EmphasisBadge({
    required this.emphasis,
  });

  final _AppointmentCardEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    switch (emphasis) {
      case _AppointmentCardEmphasis.today:
        return const AppointmentMiniBadge(label: 'Prioritaire');
      case _AppointmentCardEmphasis.pending:
        return const AppointmentMiniBadge(label: 'À traiter');
      case _AppointmentCardEmphasis.upcoming:
        return const AppointmentMiniBadge(label: 'À venir');
      case _AppointmentCardEmphasis.past:
        return const AppointmentMiniBadge(label: 'Passé');
      case _AppointmentCardEmphasis.cancelled:
        return const AppointmentMiniBadge(label: 'Clos');
    }
  }
}

bool _belongsToProfessional({
  required Appointment appointment,
  required ProfessionalProfile profile,
  required AppUser? authUser,
}) {
  final appointmentPractitionerId = _normalizeKey(appointment.practitionerId);
  final appointmentPractitionerName = _normalizeSearch(appointment.practitionerName);

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

bool _matchesQuery(Appointment appointment, String query) {
  if (query.isEmpty) return true;

  final haystack = _normalizeSearch(
    '${appointment.patientFullName} '
    '${appointment.patientPhoneE164} '
    '${appointment.reason} '
    '${appointment.slot}',
  );

  return haystack.contains(query);
}

bool _isPendingAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.pending;
}

bool _isTodayConfirmedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.confirmed &&
      AppDateFormatters.isToday(appointment.scheduledAt);
}

bool _isUpcomingConfirmedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.confirmed &&
      appointment.isUpcoming;
}

bool _isPastConfirmedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.confirmed &&
      !appointment.isUpcoming;
}

bool _isDeclinedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.declinedByProfessional;
}

bool _isPatientCancelledAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.cancelledByPatient;
}

String _normalizeKey(String value) {
  return value.trim();
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}