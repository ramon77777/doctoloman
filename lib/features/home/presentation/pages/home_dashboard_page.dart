import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../medical_records/presentation/providers/medical_records_providers.dart';
import '../../../profile/presentation/providers/patient_profile_providers.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(patientProfileProvider);
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final recordsAsync = ref.watch(medicalRecordsListProvider);

    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final profile = profileAsync.valueOrNull;

    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : (authState.user?.name.trim().isNotEmpty == true
            ? authState.user!.name.trim()
            : 'Utilisateur');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Docto'Loman"),
        actions: [
          IconButton(
            tooltip: 'Mon profil',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientProfileProvider);
            ref.invalidate(appointmentsListProvider);
            ref.invalidate(medicalRecordsListProvider);

            await Future.wait([
              ref.read(patientProfileProvider.future),
              ref.read(appointmentsListProvider.future),
              ref.read(medicalRecordsListProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DashboardHeader(
                title: 'Bonjour $displayName',
                subtitle:
                    'Gérez vos demandes, vos rendez-vous et vos accès santé simplement.',
              ),
              const SizedBox(height: 16),
              _QuickSearchCard(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.searchResults,
                    arguments: const SearchResultsArgs(
                      initialWhat: '',
                      initialWhere: '',
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              appointmentsAsync.when(
                data: (items) {
                  final pending = items
                      .where((a) => a.status == AppointmentStatus.pending)
                      .toList()
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                  final upcomingConfirmed = items
                      .where(
                        (a) =>
                            a.isUpcoming &&
                            a.status == AppointmentStatus.confirmed,
                      )
                      .toList()
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

                  final closed = items
                      .where((a) => a.isCancelledLike)
                      .toList()
                    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                  return Column(
                    children: [
                      _NextAppointmentsCard(
                        items: upcomingConfirmed.take(3).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(AppRoutes.appointments);
                        },
                      ),
                      const SizedBox(height: 12),
                      _PendingAppointmentsCard(
                        items: pending.take(3).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(AppRoutes.appointments);
                        },
                      ),
                      const SizedBox(height: 12),
                      _CancelledAppointmentsCard(
                        items: closed.take(2).toList(),
                        onOpenAll: () {
                          Navigator.of(context).pushNamed(AppRoutes.appointments);
                        },
                      ),
                    ],
                  );
                },
                loading: () => const _LoadingAppointmentsCard(),
                error: (e, _) => _DashboardInfoCard(
                  title: 'Mes rendez-vous',
                  icon: Icons.event_note_outlined,
                  child: Text(
                    'Impossible de charger les rendez-vous : $e',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              recordsAsync.when(
                data: (items) => _DashboardInfoCard(
                  title: 'Mes documents médicaux',
                  icon: Icons.folder_open_outlined,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          items.isEmpty
                              ? 'Aucun document enregistré pour le moment.'
                              : '${items.length} document(s) disponible(s).',
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.medicalRecords);
                        },
                        child: const Text('Ouvrir'),
                      ),
                    ],
                  ),
                ),
                loading: () => const _DashboardInfoCard(
                  title: 'Mes documents médicaux',
                  icon: Icons.folder_open_outlined,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => _DashboardInfoCard(
                  title: 'Mes documents médicaux',
                  icon: Icons.folder_open_outlined,
                  child: Text(
                    'Impossible de charger les documents : $e',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _QuickActionsGrid(
                onSearchDoctors: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.searchResults,
                    arguments: const SearchResultsArgs(
                      initialWhat: '',
                      initialWhere: '',
                    ),
                  );
                },
                onAppointments: () {
                  Navigator.of(context).pushNamed(AppRoutes.appointments);
                },
                onOnDutyPharmacies: () {
                  Navigator.of(context).pushNamed(AppRoutes.pharmaciesOnDuty);
                },
                onMedicalRecords: () {
                  Navigator.of(context).pushNamed(AppRoutes.medicalRecords);
                },
                onProfile: () {
                  Navigator.of(context).pushNamed(AppRoutes.profile);
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confiance & confidentialité',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos données sensibles doivent rester hébergées localement en Côte d’Ivoire. L’accès aux informations de santé se fait sous consentement.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _QuickSearchCard extends StatelessWidget {
  const _QuickSearchCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.search,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rechercher un professionnel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Médecin, spécialité, établissement…'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardInfoCard extends StatelessWidget {
  const _DashboardInfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadingAppointmentsCard extends StatelessWidget {
  const _LoadingAppointmentsCard();

  @override
  Widget build(BuildContext context) {
    return const _DashboardInfoCard(
      title: 'Mes rendez-vous',
      icon: Icons.event_note_outlined,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _NextAppointmentsCard extends StatelessWidget {
  const _NextAppointmentsCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return _DashboardInfoCard(
      title: 'Mes prochains rendez-vous confirmés',
      icon: Icons.event_available_outlined,
      child: items.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun rendez-vous confirmé à venir.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onOpenAll,
                  child: const Text('Voir mes rendez-vous'),
                ),
              ],
            )
          : Column(
              children: [
                for (final item in items) ...[
                  _AppointmentPreviewTile(
                    appointment: item,
                    badge: 'Confirmé',
                  ),
                  if (item != items.last) const Divider(height: 20),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onOpenAll,
                    child: const Text('Voir tous mes rendez-vous'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PendingAppointmentsCard extends StatelessWidget {
  const _PendingAppointmentsCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _DashboardInfoCard(
      title: 'Mes demandes envoyées',
      icon: Icons.pending_actions_outlined,
      child: items.isEmpty
          ? Text(
              'Aucune demande en attente.',
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final item in items) ...[
                  _AppointmentPreviewTile(
                    appointment: item,
                    badge: 'Réponse attendue',
                  ),
                  if (item != items.last) const Divider(height: 20),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onOpenAll,
                    child: const Text('Voir toutes mes demandes'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CancelledAppointmentsCard extends StatelessWidget {
  const _CancelledAppointmentsCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<Appointment> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DashboardInfoCard(
      title: 'Demandes ou rendez-vous clos',
      icon: Icons.event_busy_outlined,
      child: Column(
        children: [
          for (final item in items) ...[
            _AppointmentPreviewTile(
              appointment: item,
              badge: _closedBadge(item),
            ),
            if (item != items.last) const Divider(height: 20),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onOpenAll,
              child: const Text('Voir l’historique'),
            ),
          ),
        ],
      ),
    );
  }

  String _closedBadge(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé par vous';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
      case AppointmentStatus.pending:
      case AppointmentStatus.confirmed:
        return 'Clos';
    }
  }
}

class _AppointmentPreviewTile extends StatelessWidget {
  const _AppointmentPreviewTile({
    required this.appointment,
    required this.badge,
  });

  final Appointment appointment;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_today_outlined,
            size: 18,
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
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(appointment.specialty),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(appointment.day)} à ${appointment.slot}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onSearchDoctors,
    required this.onAppointments,
    required this.onOnDutyPharmacies,
    required this.onMedicalRecords,
    required this.onProfile,
  });

  final VoidCallback onSearchDoctors;
  final VoidCallback onAppointments;
  final VoidCallback onOnDutyPharmacies;
  final VoidCallback onMedicalRecords;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          children: [
            _DashboardActionCard(
              icon: Icons.medical_services_outlined,
              title: 'Consulter',
              subtitle: 'Rechercher un médecin',
              onTap: onSearchDoctors,
            ),
            _DashboardActionCard(
              icon: Icons.event_note_outlined,
              title: 'Rendez-vous',
              subtitle: 'Voir mes rendez-vous',
              onTap: onAppointments,
            ),
            _DashboardActionCard(
              icon: Icons.local_pharmacy_outlined,
              title: 'Pharmacies',
              subtitle: 'Voir les pharmacies de garde',
              onTap: onOnDutyPharmacies,
            ),
            _DashboardActionCard(
              icon: Icons.folder_open_outlined,
              title: 'Documents',
              subtitle: 'Voir mes documents médicaux',
              onTap: onMedicalRecords,
            ),
            _DashboardActionCard(
              icon: Icons.person_outline,
              title: 'Mon profil',
              subtitle: 'Gérer mon compte',
              onTap: onProfile,
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
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
  final m = months[d.month - 1];
  return '${d.day} $m ${d.year}';
}