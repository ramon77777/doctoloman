import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../data/mock_search_data.dart';
import '../../domain/search_item.dart';
import '../providers/search_providers.dart';

class SearchResultsPage extends ConsumerStatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.initialWhat,
    required this.initialWhere,
  });

  final String initialWhat;
  final String initialWhere;

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late final TextEditingController _whatCtrl;
  late final TextEditingController _whereCtrl;
  late final SearchSeed _seed;

  @override
  void initState() {
    super.initState();

    _seed = SearchSeed(
      initialWhat: widget.initialWhat,
      initialWhere: widget.initialWhere,
    );

    _whatCtrl = TextEditingController(text: widget.initialWhat);
    _whereCtrl = TextEditingController(text: widget.initialWhere);

    final where = widget.initialWhere.trim();
    final maybeCity = MockSearchData.cities().firstWhere(
      (city) => city.toLowerCase() == where.toLowerCase(),
      orElse: () => '',
    );

    if (maybeCity.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchFiltersProvider(_seed).notifier).setCity(maybeCity);
      });
    }
  }

  @override
  void dispose() {
    _whatCtrl.dispose();
    _whereCtrl.dispose();
    super.dispose();
  }

  void _syncWhat(String value) {
    ref.read(searchFiltersProvider(_seed).notifier).setWhat(value);
  }

  void _syncWhere(String value) {
    ref.read(searchFiltersProvider(_seed).notifier).setWhere(value);
  }

  void _toggleAvailableSoon() {
    ref.read(searchFiltersProvider(_seed).notifier).toggleAvailableSoon();
  }

  void _openDetail(SearchItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.practitionerDetail,
      arguments: PractitionerDetailArgs(item: item),
    );
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(seed: _seed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider(_seed));
    final resultsAsync = ref.watch(searchResultsProvider(_seed));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _SearchInputsCard(
              whatController: _whatCtrl,
              whereController: _whereCtrl,
              availableSoonOnly: filters.availableSoonOnly,
              filtersLabel: _filtersButtonLabel(filters),
              onWhatChanged: _syncWhat,
              onWhereChanged: _syncWhere,
              onToggleAvailableSoon: _toggleAvailableSoon,
              onOpenFilters: _openFiltersSheet,
            ),
            const SizedBox(height: 14),
            _ActiveFiltersSummary(filters: filters),
            const SizedBox(height: 14),
            resultsAsync.when(
              data: (items) => _ResultsSection(
                items: items,
                onOpenDetail: _openDetail,
              ),
              loading: () => const _ResultsLoadingState(),
              error: (error, _) => _ResultsErrorState(
                message: 'Impossible de charger les résultats.\n$error',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filtersButtonLabel(SearchFilters filters) {
    final cityPart = filters.city == null ? 'Toutes villes' : filters.city!;
    final sortPart = switch (filters.sortMode) {
      SortMode.recommended => 'Recommandé',
      SortMode.ratingDesc => 'Meilleure note',
      SortMode.priceAsc => 'Prix croissant',
      SortMode.priceDesc => 'Prix décroissant',
      SortMode.distanceAsc => 'Distance',
    };

    return 'Filtrer • $cityPart • $sortPart';
  }
}

class _SearchInputsCard extends StatelessWidget {
  const _SearchInputsCard({
    required this.whatController,
    required this.whereController,
    required this.availableSoonOnly,
    required this.filtersLabel,
    required this.onWhatChanged,
    required this.onWhereChanged,
    required this.onToggleAvailableSoon,
    required this.onOpenFilters,
  });

  final TextEditingController whatController;
  final TextEditingController whereController;
  final bool availableSoonOnly;
  final String filtersLabel;
  final ValueChanged<String> onWhatChanged;
  final ValueChanged<String> onWhereChanged;
  final VoidCallback onToggleAvailableSoon;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: whatController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Spécialité / médecin / établissement',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onWhatChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: whereController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Localisation',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              onChanged: onWhereChanged,
              onSubmitted: onWhereChanged,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onToggleAvailableSoon,
                    child: Text(
                      availableSoonOnly
                          ? 'Disponible bientôt ✓'
                          : 'Disponible bientôt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenFilters,
                    child: Text(
                      filtersLabel,
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
    );
  }
}

class _ActiveFiltersSummary extends StatelessWidget {
  const _ActiveFiltersSummary({required this.filters});

  final SearchFilters filters;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filters.availableSoonOnly) {
      chips.add(
        const _SummaryChip(
          icon: Icons.schedule,
          label: 'Disponible bientôt',
        ),
      );
    }

    if (filters.city != null && filters.city!.trim().isNotEmpty) {
      chips.add(
        _SummaryChip(
          icon: Icons.location_city_outlined,
          label: filters.city!,
        ),
      );
    }

    chips.add(
      _SummaryChip(
        icon: Icons.swap_vert,
        label: _sortLabel(filters.sortMode),
      ),
    );

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  String _sortLabel(SortMode mode) {
    return switch (mode) {
      SortMode.recommended => 'Recommandé',
      SortMode.ratingDesc => 'Meilleure note',
      SortMode.priceAsc => 'Prix croissant',
      SortMode.priceDesc => 'Prix décroissant',
      SortMode.distanceAsc => 'Distance',
    };
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.items,
    required this.onOpenDetail,
  });

  final List<SearchItem> items;
  final void Function(SearchItem item) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ResultsEmptyState();
    }

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${items.length} résultat(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ResultCard(
              item: item,
              onTap: () => onOpenDetail(item),
            ),
          ),
      ],
    );
  }
}

class _ResultsEmptyState extends StatelessWidget {
  const _ResultsEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 42,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun résultat trouvé',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Essaie une autre spécialité, un autre nom ou une autre localisation.',
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

class _ResultsLoadingState extends StatelessWidget {
  const _ResultsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ResultsErrorState extends StatelessWidget {
  const _ResultsErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: cs.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.onTap,
  });

  final SearchItem item;
  final VoidCallback onTap;

  IconData _typeIcon(SearchItemType type) {
    switch (type) {
      case SearchItemType.doctor:
        return Icons.medical_services_outlined;
      case SearchItemType.clinic:
        return Icons.local_hospital_outlined;
      case SearchItemType.pharmacy:
        return Icons.local_pharmacy_outlined;
    }
  }

  String _typeLabel(SearchItemType type) {
    switch (type) {
      case SearchItemType.doctor:
        return 'Médecin';
      case SearchItemType.clinic:
        return 'Clinique';
      case SearchItemType.pharmacy:
        return 'Pharmacie';
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    final first = parts.first[0];
    final second = parts.length >= 2 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
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
                child: Center(
                  child: Text(
                    _initials(item.displayName),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isVerified)
                          const _Tag(
                            icon: Icons.verified,
                            label: 'Vérifié',
                            tone: _TagTone.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.specialty,
                      style: TextStyle(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.locationLabel,
                            style: TextStyle(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag(
                          icon: Icons.star,
                          label:
                              '${item.rating.toStringAsFixed(1)} (${item.reviewCount})',
                          tone: _TagTone.neutral,
                        ),
                        _Tag(
                          icon: _typeIcon(item.type),
                          label: _typeLabel(item.type),
                          tone: _TagTone.neutral,
                        ),
                        _Tag(
                          icon: Icons.payments_outlined,
                          label: item.priceLabel,
                          tone: _TagTone.neutral,
                        ),
                        if (item.isAvailableSoon)
                          const _Tag(
                            icon: Icons.schedule,
                            label: 'Disponible bientôt',
                            tone: _TagTone.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TagTone { neutral, success, warning }

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (bg, fg) = switch (tone) {
      _TagTone.success => (cs.primaryContainer, cs.onPrimaryContainer),
      _TagTone.warning => (cs.tertiaryContainer, cs.onTertiaryContainer),
      _TagTone.neutral => (cs.surfaceContainerHighest, cs.onSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.seed});

  final SearchSeed seed;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late String? _city;
  late bool _availableSoonOnly;
  late SortMode _sortMode;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchFiltersProvider(widget.seed));
    _city = filters.city;
    _availableSoonOnly = filters.availableSoonOnly;
    _sortMode = filters.sortMode;
  }

  String _label(SortMode mode) {
    return switch (mode) {
      SortMode.recommended => 'Recommandé',
      SortMode.ratingDesc => 'Meilleure note',
      SortMode.priceAsc => 'Prix croissant',
      SortMode.priceDesc => 'Prix décroissant',
      SortMode.distanceAsc => 'Distance',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(availableSearchCitiesProvider);

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
                  value: _availableSoonOnly,
                  onChanged: (value) {
                    setState(() => _availableSoonOnly = value);
                  },
                  title: const Text('Disponible bientôt uniquement'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ville',
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
                      selected: _city == null,
                      onSelected: (_) => setState(() => _city = null),
                    ),
                    for (final city in cities)
                      ChoiceChip(
                        label: Text(city),
                        selected: _city == city,
                        onSelected: (_) => setState(() => _city = city),
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
                    child: RadioGroup<SortMode>(
                      groupValue: _sortMode,
                      onChanged: (SortMode? value) {
                        if (value == null) return;
                        setState(() => _sortMode = value);
                      },
                      child: Column(
                        children: [
                          for (final mode in SortMode.values)
                            RadioListTile<SortMode>(
                              value: mode,
                              title: Text(_label(mode)),
                              contentPadding: EdgeInsets.zero,
                            ),
                        ],
                      ),
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
                            _city = null;
                            _availableSoonOnly = false;
                            _sortMode = SortMode.recommended;
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
                            searchFiltersProvider(widget.seed).notifier,
                          );

                          notifier.setCity(_city);
                          notifier.setAvailableSoonOnly(_availableSoonOnly);
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
}