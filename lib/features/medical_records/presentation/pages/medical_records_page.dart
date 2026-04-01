import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../domain/medical_record.dart';
import '../providers/medical_records_providers.dart';

class MedicalRecordsPage extends ConsumerStatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  ConsumerState<MedicalRecordsPage> createState() =>
      _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends ConsumerState<MedicalRecordsPage> {
  late final TextEditingController _queryCtrl;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(medicalRecordsListProvider);
    await ref.read(medicalRecordsListProvider.future);
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _MedicalRecordsFiltersSheet(),
    );
  }

  void _syncQueryControllerIfNeeded(String query) {
    if (_queryCtrl.text == query) return;

    _queryCtrl.value = _queryCtrl.value.copyWith(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(medicalRecordsListProvider);
    final filteredItems = ref.watch(filteredMedicalRecordsProvider);
    final filters = ref.watch(medicalRecordsFiltersProvider);

    _syncQueryControllerIfNeeded(filters.query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes documents médicaux'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(medicalRecordsListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.medicalRecordCreate);
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: recordsAsync.when(
          data: (allItems) {
            if (allItems.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    _EmptyRecordsState(),
                  ],
                ),
              );
            }

            final sensitiveCount =
                allItems.where((item) => item.isSensitive).length;
            final latestRecord = allItems.first;
            final groupedItems = _groupMedicalRecords(filteredItems);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _InfoBanner(
                    text:
                        'Dans cette version, les documents médicaux mock sont stockés localement sur l’appareil.',
                  ),
                  const SizedBox(height: 14),
                  _RecordsOverviewCard(
                    totalCount: allItems.length,
                    filteredCount: filteredItems.length,
                    sensitiveCount: sensitiveCount,
                    latestRecordDate: latestRecord.recordDate,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: _queryCtrl,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: 'Rechercher un document',
                              hintText: 'Titre, source, résumé...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: filters.query.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Effacer',
                                      onPressed: () {
                                        _queryCtrl.clear();
                                        ref
                                            .read(
                                              medicalRecordsFiltersProvider
                                                  .notifier,
                                            )
                                            .clearQuery();
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                            onChanged: (value) {
                              ref
                                  .read(
                                    medicalRecordsFiltersProvider.notifier,
                                  )
                                  .setQuery(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(
                                        medicalRecordsFiltersProvider.notifier,
                                      )
                                      .toggleSensitiveOnly(),
                                  icon: Icon(
                                    filters.sensitiveOnly
                                        ? Icons.shield
                                        : Icons.shield_outlined,
                                  ),
                                  label: Text(
                                    filters.sensitiveOnly
                                        ? 'Sensible uniquement ✓'
                                        : 'Sensible uniquement',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _openFiltersSheet,
                                  child: Text(
                                    _filtersButtonLabel(filters),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle(
                    title: 'Documents disponibles',
                    subtitle:
                        'Consultez vos documents enregistrés localement',
                    icon: Icons.folder_open_outlined,
                  ),
                  const SizedBox(height: 10),
                  if (filteredItems.isEmpty)
                    const _EmptyFilteredState()
                  else
                    ...groupedItems.entries.map(
                      (entry) => _MedicalRecordsGroupSection(
                        title: entry.key,
                        items: entry.value,
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _ErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(medicalRecordsListProvider),
          ),
        ),
      ),
    );
  }

  String _filtersButtonLabel(MedicalRecordsFilters filters) {
    final categoryPart = filters.category == null
        ? 'Toutes catégories'
        : _categoryLabel(filters.category!);

    final sortPart = switch (filters.sortMode) {
      MedicalRecordsSortMode.newestFirst => 'Plus récents',
      MedicalRecordsSortMode.oldestFirst => 'Plus anciens',
      MedicalRecordsSortMode.titleAsc => 'Titre A-Z',
    };

    return 'Filtrer • $categoryPart • $sortPart';
  }

  String _categoryLabel(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return 'Ordonnance';
      case MedicalRecordCategory.labResult:
        return 'Analyse';
      case MedicalRecordCategory.imaging:
        return 'Imagerie';
      case MedicalRecordCategory.certificate:
        return 'Certificat';
      case MedicalRecordCategory.report:
        return 'Compte rendu';
      case MedicalRecordCategory.other:
        return 'Autre';
    }
  }
}

class _MedicalRecordsGroupSection extends StatelessWidget {
  const _MedicalRecordsGroupSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<MedicalRecord> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(
            title: title,
            count: items.length,
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MedicalRecordCard(
                record: item,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.medicalRecordDetail,
                    arguments: MedicalRecordDetailArgs(
                      recordId: item.id,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _MedicalRecordsFiltersSheet extends ConsumerStatefulWidget {
  const _MedicalRecordsFiltersSheet();

  @override
  ConsumerState<_MedicalRecordsFiltersSheet> createState() =>
      _MedicalRecordsFiltersSheetState();
}

class _MedicalRecordsFiltersSheetState
    extends ConsumerState<_MedicalRecordsFiltersSheet> {
  MedicalRecordCategory? _category;
  late bool _sensitiveOnly;
  late MedicalRecordsSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(medicalRecordsFiltersProvider);
    _category = filters.category;
    _sensitiveOnly = filters.sensitiveOnly;
    _sortMode = filters.sortMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Filtres & tri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _sensitiveOnly,
                  onChanged: (value) {
                    setState(() => _sensitiveOnly = value);
                  },
                  title: const Text('Documents sensibles uniquement'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Catégorie',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Toutes'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final category in MedicalRecordCategory.values)
                      ChoiceChip(
                        label: Text(_categoryLabel(category)),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Trier par',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final mode in MedicalRecordsSortMode.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _sortMode = mode),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _sortMode == mode
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _sortMode == mode
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _sortMode == mode
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 20,
                                      color: _sortMode == mode
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(_sortLabel(mode)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _category = null;
                            _sensitiveOnly = false;
                            _sortMode = MedicalRecordsSortMode.newestFirst;
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final notifier = ref.read(
                            medicalRecordsFiltersProvider.notifier,
                          );

                          notifier.setCategory(_category);
                          notifier.setSensitiveOnly(_sensitiveOnly);
                          notifier.setSortMode(_sortMode);

                          Navigator.of(context).pop();
                        },
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return 'Ordonnance';
      case MedicalRecordCategory.labResult:
        return 'Analyse';
      case MedicalRecordCategory.imaging:
        return 'Imagerie';
      case MedicalRecordCategory.certificate:
        return 'Certificat';
      case MedicalRecordCategory.report:
        return 'Compte rendu';
      case MedicalRecordCategory.other:
        return 'Autre';
    }
  }

  String _sortLabel(MedicalRecordsSortMode mode) {
    switch (mode) {
      case MedicalRecordsSortMode.newestFirst:
        return 'Plus récents';
      case MedicalRecordsSortMode.oldestFirst:
        return 'Plus anciens';
      case MedicalRecordsSortMode.titleAsc:
        return 'Titre A-Z';
    }
  }
}

class _RecordsOverviewCard extends StatelessWidget {
  const _RecordsOverviewCard({
    required this.totalCount,
    required this.filteredCount,
    required this.sensitiveCount,
    required this.latestRecordDate,
  });

  final int totalCount;
  final int filteredCount;
  final int sensitiveCount;
  final DateTime latestRecordDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniBadge(label: '$totalCount document(s) total'),
                _MiniBadge(label: '$filteredCount affiché(s)'),
                _MiniBadge(label: '$sensitiveCount sensible(s)'),
                _MiniBadge(
                  label: 'Dernier : ${_formatDate(latestRecordDate)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Les documents sensibles doivent être consultés dans un cadre protégé, avec contrôle d’accès et traçabilité complète côté backend dans la version cible.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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

class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard({
    required this.record,
    required this.onTap,
  });

  final MedicalRecord record;
  final VoidCallback onTap;

  IconData _iconFor(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return Icons.receipt_long_outlined;
      case MedicalRecordCategory.labResult:
        return Icons.science_outlined;
      case MedicalRecordCategory.imaging:
        return Icons.image_search_outlined;
      case MedicalRecordCategory.certificate:
        return Icons.verified_outlined;
      case MedicalRecordCategory.report:
        return Icons.article_outlined;
      case MedicalRecordCategory.other:
        return Icons.description_outlined;
    }
  }

  String _categoryLabel(MedicalRecordCategory category) {
    switch (category) {
      case MedicalRecordCategory.prescription:
        return 'Ordonnance';
      case MedicalRecordCategory.labResult:
        return 'Analyse';
      case MedicalRecordCategory.imaging:
        return 'Imagerie';
      case MedicalRecordCategory.certificate:
        return 'Certificat';
      case MedicalRecordCategory.report:
        return 'Compte rendu';
      case MedicalRecordCategory.other:
        return 'Document';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(record.category),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.sourceLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      record.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniBadge(label: _categoryLabel(record.category)),
                        _MiniBadge(label: _formatDate(record.recordDate)),
                        if (record.isSensitive)
                          const _MiniBadge(label: 'Sensible'),
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

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
          Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyRecordsState extends StatelessWidget {
  const _EmptyRecordsState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun document médical',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Ajoute un document médical pour commencer.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  const _EmptyFilteredState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun document ne correspond aux filtres',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Essaie une autre recherche ou réinitialise les filtres.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Erreur',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
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

Map<String, List<MedicalRecord>> _groupMedicalRecords(
  List<MedicalRecord> items,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final groups = <String, List<MedicalRecord>>{
    'Aujourd’hui': [],
    '7 derniers jours': [],
    '30 derniers jours': [],
    'Plus anciens': [],
  };

  for (final item in items) {
    final recordDay = DateTime(
      item.recordDate.year,
      item.recordDate.month,
      item.recordDate.day,
    );

    final difference = today.difference(recordDay).inDays;

    if (difference <= 0) {
      groups['Aujourd’hui']!.add(item);
    } else if (difference <= 7) {
      groups['7 derniers jours']!.add(item);
    } else if (difference <= 30) {
      groups['30 derniers jours']!.add(item);
    } else {
      groups['Plus anciens']!.add(item);
    }
  }

  groups.removeWhere((key, value) => value.isEmpty);
  return groups;
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
  final month = months[d.month - 1];
  return '${d.day} $month ${d.year}';
}