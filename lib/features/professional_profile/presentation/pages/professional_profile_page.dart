import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../providers/professional_profile_providers.dart';

class ProfessionalProfilePage extends ConsumerWidget {
  const ProfessionalProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(professionalProfileProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final languagesLabel = profile.languages.isEmpty
        ? 'Non renseigné'
        : profile.languages.join(', ');

    final bioLabel = profile.bio.trim().isEmpty
        ? 'Aucune présentation renseignée.'
        : profile.bio.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil professionnel'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.professionalProfileEdit);
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: cs.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.specialty,
                            style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.structureName,
                            style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (profile.isVerified)
                                const _Badge(
                                  label: 'Profil vérifié',
                                  icon: Icons.verified_outlined,
                                ),
                              _Badge(
                                label: profile.consultationFeeLabel,
                                icon: Icons.payments_outlined,
                              ),
                              _Badge(
                                label: profile.city,
                                icon: Icons.location_on_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.professionalProfileEdit,
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier mon profil'),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Informations principales',
              icon: Icons.badge_outlined,
              children: [
                _Line(label: 'Nom affiché', value: profile.displayName),
                _Line(label: 'Spécialité', value: profile.specialty),
                _Line(label: 'Structure', value: profile.structureName),
                _Line(label: 'Téléphone', value: profile.phone),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Localisation',
              icon: Icons.location_on_outlined,
              children: [
                _Line(label: 'Adresse', value: profile.address),
                _Line(label: 'Quartier', value: profile.area),
                _Line(label: 'Ville', value: profile.city),
                _Line(label: 'Résumé', value: profile.fullLocation),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Présentation',
              icon: Icons.description_outlined,
              children: [
                Text(
                  bioLabel,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Paramètres métier',
              icon: Icons.settings_suggest_outlined,
              children: [
                _Line(label: 'Langues', value: languagesLabel),
                _Line(
                  label: 'Consultation',
                  value: profile.consultationFeeLabel,
                ),
                const _Line(
                  label: 'Disponibilités',
                  value: 'Gérées dans la section créneaux',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Visibilité côté patient',
              icon: Icons.visibility_outlined,
              children: [
                Text(
                  'Les informations du profil professionnel alimentent la fiche visible côté patient dans la recherche, le détail praticien et la prise de rendez-vous.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pensez à garder vos coordonnées, votre adresse et votre présentation à jour pour améliorer la confiance et la conversion côté patient.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
              children: [
                Icon(icon, size: 20, color: cs.primary),
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
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
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
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

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
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}