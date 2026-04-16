import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/medical_access.dart';
import '../providers/medical_access_providers.dart';

class ProfessionalAuthorizedPatientsPage extends ConsumerStatefulWidget {
  const ProfessionalAuthorizedPatientsPage({super.key});

  @override
  ConsumerState<ProfessionalAuthorizedPatientsPage> createState() =>
      _ProfessionalAuthorizedPatientsPageState();
}

class _ProfessionalAuthorizedPatientsPageState
    extends ConsumerState<ProfessionalAuthorizedPatientsPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_handleSearchChanged);
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

  String _normalizeSearch(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<MedicalAccess> _filterItems(
    List<MedicalAccess> items,
    String query,
  ) {
    final normalizedQuery = _normalizeSearch(query);
    if (normalizedQuery.isEmpty) {
      return List<MedicalAccess>.unmodifiable(
        [...items]..sort((a, b) => b.grantedAt.compareTo(a.grantedAt)),
      );
    }

    final filtered = items.where((item) {
      final haystack = _normalizeSearch(
        '${item.patientName} ${item.patientId} ${item.professionalId}',
      );
      return haystack.contains(normalizedQuery);
    }).toList()
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

    return List<MedicalAccess>.unmodifiable(filtered);
  }

  void _openAuthorizedPatientRecord(
    BuildContext context,
    MedicalAccess access,
  ) {
    final activeAccess = ref.read(
      activeMedicalAccessForCurrentProfessionalByPatientIdProvider(
        access.patientId,
      ),
    );

    if (activeAccess == null || !activeAccess.isActive) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Accès non autorisé ou révoqué pour ce dossier patient.',
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.professionalPatientMedicalRecords,
      arguments: ProfessionalPatientMedicalRecordsArgs(
        patientId: access.patientId,
        patientName: access.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated ||
        user == null ||
        user.role != AppUserRole.professional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patients autorisés'),
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

    final accesses = ref.watch(professionalMedicalAccessProvider);
    final filteredAccesses = _filterItems(accesses, _searchCtrl.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients autorisés'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _InfoCard(
              title: 'Accès autorisés',
              message:
                  'Cette liste contient uniquement les patients qui vous ont explicitement autorisé à consulter leur dossier médical.',
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              totalCount: accesses.length,
              visibleCount: filteredAccesses.length,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Rechercher un patient',
                hintText: 'Nom du patient...',
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
            const SizedBox(height: 16),
            const _SectionHeader(
              title: 'Patients avec accès actif',
              subtitle: 'Classés du plus récent au plus ancien',
            ),
            const SizedBox(height: 10),
            if (accesses.isEmpty)
              const _EmptyStateCard(
                title: 'Aucun accès actif',
                message:
                    'Aucun patient ne vous a encore donné accès à son dossier médical.',
              )
            else if (filteredAccesses.isEmpty)
              const _EmptyStateCard(
                title: 'Aucun résultat',
                message:
                    'Aucun patient autorisé ne correspond à votre recherche.',
              )
            else
              ...filteredAccesses.map(
                (access) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AuthorizedPatientCard(
                    access: access,
                    onOpen: () => _openAuthorizedPatientRecord(context, access),
                  ),
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
            Icon(Icons.verified_user_outlined, color: cs.primary),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.visibleCount,
  });

  final int totalCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniBadge(label: '$totalCount accès actif(s)', colorScheme: cs),
            _MiniBadge(label: '$visibleCount affiché(s)', colorScheme: cs),
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
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
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
    );
  }
}

class _AuthorizedPatientCard extends StatelessWidget {
  const _AuthorizedPatientCard({
    required this.access,
    required this.onOpen,
  });

  final MedicalAccess access;
  final VoidCallback onOpen;

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
            Row(
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
                    Icons.person_outline,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        access.patientName,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accès accordé le ${_formatDateTime(access.grantedAt)}',
                        style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniBadge(
                            label: 'Accès actif',
                            colorScheme: cs,
                          ),
                          _MiniBadge(
                            label: 'Patient autorisé',
                            colorScheme: cs,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_shared_outlined),
                label: const Text('Ouvrir le dossier'),
              ),
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
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 36,
              color: cs.onSurfaceVariant,
            ),
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

String _formatDateTime(DateTime value) {
  final d = value;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final mon = d.month.toString().padLeft(2, '0');
  return '$dd/$mon/${d.year} à $hh:$mm';
}