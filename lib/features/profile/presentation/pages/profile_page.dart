import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/patient_profile.dart';
import '../providers/patient_profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(patientProfileProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Future<void> handleLogout() async {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Se déconnecter'),
              content: const Text(
                'Voulez-vous vraiment vous déconnecter ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Confirmer'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      await ref.read(authControllerProvider.notifier).logout();
      await ref.read(patientProfileControllerProvider).clear();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous êtes déconnecté.')),
      );

      Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Impossible de charger le profil : $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (profile) {
            final displayName = profile?.name.trim().isNotEmpty == true
                ? profile!.name.trim()
                : (authState.user?.name ?? 'Utilisateur');

            final displayPhone = profile?.phone.trim().isNotEmpty == true
                ? profile!.phone.trim()
                : (authState.user?.phone ?? 'Téléphone non disponible');

            final displayCity = profile?.city?.trim().isNotEmpty == true
                ? profile!.city!.trim()
                : 'Non renseignée';

            final displayDistrict =
                profile?.district?.trim().isNotEmpty == true
                    ? profile!.district!.trim()
                    : 'Non renseigné';

            final displayAddress =
                profile?.address?.trim().isNotEmpty == true
                    ? profile!.address!.trim()
                    : 'Non renseignée';

            final displayBirthDate = profile?.birthDate != null
                ? _formatDate(profile!.birthDate!)
                : 'Non renseignée';

            final displayGender = _genderLabel(profile?.gender);

            final displayBloodGroup =
                profile?.bloodGroup?.trim().isNotEmpty == true
                    ? profile!.bloodGroup!.trim()
                    : 'Non renseigné';

            final displayAllergies =
                profile?.allergies?.trim().isNotEmpty == true
                    ? profile!.allergies!.trim()
                    : 'Non renseigné';

            final displayMedicalNotes =
                profile?.medicalNotes?.trim().isNotEmpty == true
                    ? profile!.medicalNotes!.trim()
                    : 'Non renseigné';

            final emergencyName =
                profile?.emergencyContactName?.trim().isNotEmpty == true
                    ? profile!.emergencyContactName!.trim()
                    : 'Non renseigné';

            final emergencyPhone =
                profile?.emergencyContactPhone?.trim().isNotEmpty == true
                    ? profile!.emergencyContactPhone!.trim()
                    : 'Non renseigné';

            final completionPercent = profile?.completionPercent ?? 0;
            final isProfileComplete = profile?.isComplete ?? false;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.person_outline,
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
                                displayName,
                                style: textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayPhone,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: completionPercent / 100,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Profil complété à $completionPercent%',
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      authState.isAuthenticated
                                          ? (authState.isLoading
                                              ? 'Mise à jour...'
                                              : 'Session active')
                                          : 'Non connecté',
                                      style: textTheme.labelLarge,
                                    ),
                                  ),
                                  if (isProfileComplete)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Profil complété',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: authState.isAuthenticated &&
                                            !authState.isLoading
                                        ? () {
                                            Navigator.of(context).pushNamed(
                                              AppRoutes.profileEdit,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Modifier'),
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
                if (!isProfileComplete) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Complétez votre profil pour une meilleure expérience et une prise en charge plus fluide.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: authState.isAuthenticated
                                ? () {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.profileEdit,
                                    );
                                  }
                                : null,
                            child: const Text('Compléter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Informations personnelles',
                  icon: Icons.badge_outlined,
                  children: [
                    _ProfileLine(label: 'Nom', value: displayName),
                    _ProfileLine(label: 'Téléphone', value: displayPhone),
                    _ProfileLine(label: 'Ville', value: displayCity),
                    _ProfileLine(
                      label: 'Commune / quartier',
                      value: displayDistrict,
                    ),
                    _ProfileLine(label: 'Adresse', value: displayAddress),
                    _ProfileLine(
                      label: 'Date de naissance',
                      value: displayBirthDate,
                    ),
                    _ProfileLine(label: 'Sexe', value: displayGender),
                    _ProfileLine(
                      label: 'Groupe sanguin',
                      value: displayBloodGroup,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Informations médicales utiles',
                  icon: Icons.medical_information_outlined,
                  children: [
                    _ProfileLine(label: 'Allergies', value: displayAllergies),
                    _ProfileLine(
                      label: 'Notes médicales',
                      value: displayMedicalNotes,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Contact d’urgence',
                  icon: Icons.contact_phone_outlined,
                  children: [
                    _ProfileLine(label: 'Nom', value: emergencyName),
                    _ProfileLine(label: 'Téléphone', value: emergencyPhone),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Documents & données',
                  icon: Icons.folder_open_outlined,
                  children: [
                    _ProfileActionTile(
                      icon: Icons.description_outlined,
                      title: 'Mes documents médicaux',
                      subtitle: 'Ordonnances, analyses, certificats',
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.medicalRecords,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Confidentialité',
                  icon: Icons.shield_outlined,
                  children: const [
                    _ProfileLine(
                      label: 'Hébergement',
                      value: 'Local / Côte d’Ivoire',
                    ),
                    _ProfileLine(
                      label: 'Accès dossier',
                      value: 'Sous consentement explicite',
                    ),
                    _ProfileLine(
                      label: 'Traçabilité',
                      value: 'Journalisation prévue côté backend',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Préférences',
                  icon: Icons.settings_outlined,
                  children: [
                    _ProfileActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Rappels de rendez-vous',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.language_outlined,
                      title: 'Langue',
                      subtitle: 'Français',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: authState.isAuthenticated && !authState.isLoading
                        ? handleLogout
                        : null,
                    icon: authState.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            );
          },
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
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
  final month = months[date.month - 1];
  return '${date.day} $month ${date.year}';
}

String _genderLabel(PatientGender? gender) {
  switch (gender) {
    case PatientGender.female:
      return 'Féminin';
    case PatientGender.male:
      return 'Masculin';
    case PatientGender.other:
      return 'Autre';
    case null:
      return 'Non renseigné';
  }
}


