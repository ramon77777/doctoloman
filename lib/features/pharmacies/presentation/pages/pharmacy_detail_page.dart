import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/pharmacy.dart';
import '../providers/pharmacy_providers.dart';

class PharmacyDetailPage extends ConsumerWidget {
  const PharmacyDetailPage({
    super.key,
    required this.pharmacyId,
  });

  final String? pharmacyId;

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _callPharmacy(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && context.mounted) {
      _showMessage(context, 'Impossible d’ouvrir l’appel téléphonique.');
    }
  }

  Future<void> _openDirections(BuildContext context, Pharmacy pharmacy) async {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;

    if (lat == null || lng == null) {
      if (context.mounted) {
        _showMessage(
          context,
          'Coordonnées GPS indisponibles pour cette pharmacie.',
        );
      }
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

    if (!ok && context.mounted) {
      _showMessage(context, 'Impossible d’ouvrir l’itinéraire.');
    }
  }

  Future<void> _copyPhone(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));

    if (context.mounted) {
      _showMessage(context, 'Numéro copié.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedId = pharmacyId?.trim();

    if (normalizedId == null || normalizedId.isEmpty) {
      return const Scaffold(
        appBar: null,
        body: SafeArea(
          child: _DetailMessageState(
            icon: Icons.local_pharmacy_outlined,
            title: 'Pharmacie introuvable',
            message: 'Aucun identifiant pharmacie valide n’a été fourni.',
          ),
        ),
      );
    }

    final pharmacyAsync = ref.watch(pharmacyByIdProvider(normalizedId));

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: pharmacyAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _DetailMessageState(
            icon: Icons.error_outline,
            title: 'Erreur de chargement',
            message: '$error',
          ),
          data: (pharmacy) {
            if (pharmacy == null) {
              return const _DetailMessageState(
                icon: Icons.search_off_outlined,
                title: 'Pharmacie introuvable',
                message: 'Cette pharmacie n’existe pas ou n’est plus disponible.',
              );
            }

            final hasCoordinates = pharmacy.hasCoordinates;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(
                  pharmacy: pharmacy,
                  hasCoordinates: hasCoordinates,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callPharmacy(context, pharmacy.phone),
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Appeler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: hasCoordinates
                            ? () => _openDirections(context, pharmacy)
                            : null,
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Itinéraire'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _copyPhone(context, pharmacy.phone),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier le numéro'),
                  ),
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Informations',
                  icon: Icons.info_outline,
                  children: [
                    _Line(label: 'Adresse', value: pharmacy.address),
                    _Line(
                      label: 'Zone',
                      value: '${pharmacy.area} • ${pharmacy.city}',
                    ),
                    _Line(label: 'Horaires', value: pharmacy.openingHours),
                    _Line(label: 'Téléphone', value: pharmacy.phone),
                    _Line(
                      label: 'Disponibilité',
                      value: pharmacy.isOnDuty
                          ? 'Pharmacie de garde'
                          : 'Horaires normaux',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Confidentialité',
                  icon: Icons.shield_outlined,
                  children: [
                    Text(
                      'La localisation, si vous activez “Autour de moi”, sert uniquement à trier les pharmacies proches et à ouvrir un itinéraire. Elle n’est pas stockée.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoSectionCard(
                  title: 'Conformité',
                  icon: Icons.verified_user_outlined,
                  children: [
                    Text(
                      'Pour Docto’Loman, les données sensibles doivent rester hébergées localement en Côte d’Ivoire. Les intégrations externes doivent être utilisées avec prudence.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.pharmacy,
    required this.hasCoordinates,
  });

  final Pharmacy pharmacy;
  final bool hasCoordinates;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.local_pharmacy_outlined,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pharmacy.name,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pharmacy.locationLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (pharmacy.isOnDuty)
                        const _Badge(
                          text: 'De garde',
                          icon: Icons.nightlight_outlined,
                        ),
                      if (hasCoordinates)
                        const _Badge(
                          text: 'Itinéraire dispo',
                          icon: Icons.navigation_outlined,
                        ),
                    ],
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

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMessageState extends StatelessWidget {
  const _DetailMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
            Icon(icon, size: 42, color: colorScheme.onSurfaceVariant),
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