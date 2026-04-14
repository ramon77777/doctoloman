import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../domain/pharmacy.dart';
import '../providers/pharmacy_providers.dart';

class PharmaciesPage extends ConsumerStatefulWidget {
  const PharmaciesPage({
    super.key,
    this.initialOnDutyOnly = false,
  });

  final bool initialOnDutyOnly;

  @override
  ConsumerState<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends ConsumerState<PharmaciesPage> {
  bool _didInit = false;
  late final TextEditingController _qCtrl;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final filters = ref.read(pharmacyFiltersProvider);

    if (widget.initialOnDutyOnly && !filters.onDutyOnly) {
      ref.read(pharmacyFiltersProvider.notifier).setOnDutyOnly(true);
    }

    _qCtrl.text = filters.query;
  }

  Future<bool> _askLocationConsent(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Activer “Autour de moi” ?'),
              content: const Text(
                'Pour trier les pharmacies par proximité, Docto’Loman a besoin de votre localisation.\n\n'
                '• Utilisation : uniquement pour le tri et l’itinéraire\n'
                '• Stockage : aucune localisation n’est enregistrée\n'
                '• Vous pouvez désactiver à tout moment',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Refuser'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Autoriser'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  String _distanceLabel(double? km) {
    if (km == null) return 'Distance inconnue';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _enableLocation() async {
    final ok = await _askLocationConsent(context);
    if (!ok) return;

    ref.read(locationConsentProvider.notifier).state = true;
    ref.read(pharmacyFiltersProvider.notifier).setUseMyLocation(true);
    ref.invalidate(userLocationProvider);

    final pos = await ref.read(userLocationProvider.future);

    if (!mounted) return;

    if (pos == null) {
      ref.read(pharmacyFiltersProvider.notifier).setUseMyLocation(false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’obtenir votre position. Vérifiez les autorisations GPS.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tri par proximité activé.')),
    );
  }

  Future<void> _recalibrate() async {
    ref.invalidate(userLocationProvider);
    final pos = await ref.read(userLocationProvider.future);

    if (!mounted) return;

    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position indisponible.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Position mise à jour.')),
    );
  }

  void _disableLocation() {
    ref.read(pharmacyFiltersProvider.notifier).setUseMyLocation(false);
    ref.read(locationConsentProvider.notifier).state = false;
    ref.invalidate(userLocationProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tri par proximité désactivé.')),
    );
  }

  void _resetAll() {
    _qCtrl.clear();
    ref.read(locationConsentProvider.notifier).state = false;
    ref.read(pharmacyFiltersProvider.notifier).resetAll();
    ref.invalidate(userLocationProvider);
  }

  void _openDetail(String id) {
    Navigator.of(context).pushNamed(
      AppRoutes.pharmacyDetail,
      arguments: PharmacyDetailArgs(pharmacyId: id),
    );
  }

  Future<void> _callPharmacy(Pharmacy pharmacy) async {
    final cleaned = pharmacy.phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir l’appel téléphonique.'),
        ),
      );
    }
  }

  Future<void> _openDirections(Pharmacy pharmacy) async {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;

    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordonnées GPS indisponibles pour cette pharmacie.'),
        ),
      );
      return;
    }

    final destination = '$lat,$lng';

    final mapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    final ok = await launchUrl(
      mapsUri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir l’itinéraire.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(pharmacyFiltersProvider);
    final pharmaciesAsync = ref.watch(pharmaciesResultsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(filters.onDutyOnly ? 'Pharmacies de garde' : 'Pharmacies'),
        actions: [
          IconButton(
            tooltip:
                filters.onDutyOnly ? 'Afficher toutes' : 'De garde uniquement',
            onPressed: () =>
                ref.read(pharmacyFiltersProvider.notifier).toggleOnDuty(),
            icon: Icon(
              filters.onDutyOnly
                  ? Icons.filter_alt_off
                  : Icons.nightlight_outlined,
            ),
          ),
          if (!filters.useMyLocation)
            IconButton(
              tooltip: 'Autour de moi',
              onPressed: _enableLocation,
              icon: const Icon(Icons.my_location),
            )
          else
            IconButton(
              tooltip: 'Désactiver',
              onPressed: _disableLocation,
              icon: const Icon(Icons.location_off),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _qCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Rechercher une pharmacie',
                      hintText: 'Nom, quartier, ville…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: filters.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer',
                              onPressed: () {
                                _qCtrl.clear();
                                ref
                                    .read(pharmacyFiltersProvider.notifier)
                                    .clearQuery();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (value) => ref
                        .read(pharmacyFiltersProvider.notifier)
                        .setQuery(value),
                  ),
                  const SizedBox(height: 10),
                  pharmaciesAsync.maybeWhen(
                    data: (view) {
                      return _CitySelector(
                        cities: view.availableCities,
                        selectedCity: view.selectedCity,
                        onChanged: (value) {
                          ref
                              .read(pharmacyFiltersProvider.notifier)
                              .setCity(value);
                        },
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('De garde'),
                          selected: filters.onDutyOnly,
                          onSelected: (_) => ref
                              .read(pharmacyFiltersProvider.notifier)
                              .toggleOnDuty(),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Autour de moi'),
                          selected: filters.useMyLocation,
                          onSelected: (_) {
                            if (filters.useMyLocation) {
                              _disableLocation();
                            } else {
                              _enableLocation();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('Réinitialiser'),
                          onPressed: _resetAll,
                        ),
                      ],
                    ),
                  ),
                  if (filters.useMyLocation) ...[
                    const SizedBox(height: 10),
                    _LocationInfoBar(
                      onRecalibrate: _recalibrate,
                      onDisable: _disableLocation,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: pharmaciesAsync.when(
                data: (view) {
                  if (view.items.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Aucune pharmacie trouvée',
                      message:
                          'Essaie une autre recherche ou désactive certains filtres.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatsBar(
                        totalCount: view.totalCount,
                        nearbyCount: view.nearbyCount,
                        onDutyCount: view.onDutyCount,
                        useMyLocation: filters.useMyLocation,
                      ),
                      if (filters.useMyLocation && !view.hasDistanceData) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'La proximité est activée, mais certaines pharmacies n’ont pas encore de coordonnées GPS exploitables. Les résultats restent affichés.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (filters.useMyLocation &&
                          view.hasDistanceData &&
                          view.nearbyItems.isEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.near_me_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aucune pharmacie trouvée à moins de 5 km. Voici les autres résultats classés par distance.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (filters.useMyLocation &&
                          view.nearbyItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const _SectionTitle(
                          title: 'Pharmacies proches',
                          subtitle: 'À moins de 5 km de votre position',
                          icon: Icons.near_me_outlined,
                        ),
                        const SizedBox(height: 10),
                        ...view.nearbyItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PharmacyTileCard(
                              pharmacy: item.pharmacy,
                              distanceLabel: _distanceLabel(item.distanceKm),
                              showDistance: true,
                              isNear: true,
                              onTap: () => _openDetail(item.pharmacy.id),
                              onCall: () => _callPharmacy(item.pharmacy),
                              onDirections: () =>
                                  _openDirections(item.pharmacy),
                            ),
                          ),
                        ),
                      ],
                      if (filters.useMyLocation && view.otherItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _SectionTitle(
                          title: view.nearbyItems.isEmpty
                              ? 'Résultats'
                              : 'Autres pharmacies',
                          subtitle: view.hasDistanceData
                              ? 'Classées par distance puis par nom'
                              : 'Classées par nom',
                          icon: Icons.list_alt_outlined,
                        ),
                        const SizedBox(height: 10),
                        ...view.otherItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PharmacyTileCard(
                              pharmacy: item.pharmacy,
                              distanceLabel: _distanceLabel(item.distanceKm),
                              showDistance: view.hasDistanceData,
                              isNear: false,
                              onTap: () => _openDetail(item.pharmacy.id),
                              onCall: () => _callPharmacy(item.pharmacy),
                              onDirections: () =>
                                  _openDirections(item.pharmacy),
                            ),
                          ),
                        ),
                      ],
                      if (!filters.useMyLocation) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Activez “Autour de moi” pour voir les pharmacies les plus proches.',
                                ),
                              ),
                              TextButton(
                                onPressed: _enableLocation,
                                child: const Text('Activer'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle(
                          title: 'Toutes les pharmacies',
                          subtitle: 'Classées par nom',
                          icon: Icons.local_pharmacy_outlined,
                        ),
                        const SizedBox(height: 10),
                        ...view.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PharmacyTileCard(
                              pharmacy: item.pharmacy,
                              distanceLabel: null,
                              showDistance: false,
                              isNear: false,
                              onTap: () => _openDetail(item.pharmacy.id),
                              onCall: () => _callPharmacy(item.pharmacy),
                              onDirections: () =>
                                  _openDirections(item.pharmacy),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Erreur',
                  message: '$error',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitySelector extends StatelessWidget {
  const _CitySelector({
    required this.cities,
    required this.selectedCity,
    required this.onChanged,
  });

  final List<String> cities;
  final String? selectedCity;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCity,
      decoration: const InputDecoration(
        labelText: 'Ville',
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Toutes les villes'),
        ),
        ...cities.map(
          (city) => DropdownMenuItem<String>(
            value: city,
            child: Text(city),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.totalCount,
    required this.nearbyCount,
    required this.onDutyCount,
    required this.useMyLocation,
  });

  final int totalCount;
  final int nearbyCount;
  final int onDutyCount;
  final bool useMyLocation;

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
          _StatChip(label: '$totalCount résultat(s)'),
          _StatChip(label: '$onDutyCount de garde'),
          if (useMyLocation) _StatChip(label: '$nearbyCount proche(s)'),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

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

class _PharmacyTileCard extends StatelessWidget {
  const _PharmacyTileCard({
    required this.pharmacy,
    required this.onTap,
    required this.onCall,
    required this.onDirections,
    required this.showDistance,
    required this.isNear,
    required this.distanceLabel,
  });

  final Pharmacy pharmacy;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final bool showDistance;
  final bool isNear;
  final String? distanceLabel;

  bool get _isOpen24h => pharmacy.openingHours.trim().toLowerCase() == '24h/24';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCoordinates =
        pharmacy.latitude != null && pharmacy.longitude != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacy.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pharmacy.locationLabel,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pharmacy.address,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          if (showDistance && distanceLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              distanceLabel!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (isNear) const _MiniBadge(label: 'Proche'),
                              if (pharmacy.isOnDuty)
                                const _MiniBadge(label: 'Garde'),
                              if (_isOpen24h)
                                const _MiniBadge(label: '24h/24'),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Appeler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasCoordinates ? onDirections : null,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Itinéraire'),
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
    final textTheme = Theme.of(context).textTheme;

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
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
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

class _LocationInfoBar extends StatelessWidget {
  const _LocationInfoBar({
    required this.onRecalibrate,
    required this.onDisable,
  });

  final VoidCallback onRecalibrate;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Autour de moi activé • tri par proximité',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRecalibrate,
            child: const Text('Recalibrer'),
          ),
          IconButton(
            tooltip: 'Désactiver',
            onPressed: onDisable,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}