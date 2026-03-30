import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/professional_profile_providers.dart';

class ProfessionalProfileEditPage extends ConsumerStatefulWidget {
  const ProfessionalProfileEditPage({super.key});

  @override
  ConsumerState<ProfessionalProfileEditPage> createState() =>
      _ProfessionalProfileEditPageState();
}

class _ProfessionalProfileEditPageState
    extends ConsumerState<ProfessionalProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _structureNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _consultationFeeCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();

  bool _isVerified = false;
  bool _isSaving = false;
  bool _initialized = false;

  List<TextEditingController> get _allControllers => [
        _displayNameCtrl,
        _specialtyCtrl,
        _structureNameCtrl,
        _phoneCtrl,
        _cityCtrl,
        _areaCtrl,
        _addressCtrl,
        _bioCtrl,
        _consultationFeeCtrl,
        _languagesCtrl,
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    final profile = ref.read(professionalProfileProvider);

    _displayNameCtrl.text = profile.displayName;
    _specialtyCtrl.text = profile.specialty;
    _structureNameCtrl.text = profile.structureName;
    _phoneCtrl.text = profile.phone;
    _cityCtrl.text = profile.city;
    _areaCtrl.text = profile.area;
    _addressCtrl.text = profile.address;
    _bioCtrl.text = profile.bio;
    _consultationFeeCtrl.text = profile.consultationFeeLabel;
    _languagesCtrl.text = profile.languages.join(', ');
    _isVerified = profile.isVerified;

    for (final controller in _allControllers) {
      controller.addListener(_onFormChanged);
    }

    _initialized = true;
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _allControllers) {
      controller.removeListener(_onFormChanged);
      controller.dispose();
    }
    super.dispose();
  }

  String _cleanText(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizePhone(String value) {
    final trimmed = value.trim();

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }

    return trimmed.replaceAll(RegExp(r'\D'), '');
  }

  String _normalizeMultilineText(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String? _requiredValidator(String? value, String label) {
    final normalized = _cleanText(value);
    if (normalized.isEmpty) {
      return '$label requis';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final normalized = _normalizePhone(value ?? '');
    if (normalized.isEmpty) return 'Téléphone requis';

    if (!RegExp(r'^\+225\d{10}$').hasMatch(normalized)) {
      return 'Format attendu : +225XXXXXXXXXX';
    }
    return null;
  }

  String? _consultationFeeValidator(String? value) {
    final normalized = _cleanText(value);
    if (normalized.isEmpty) {
      return 'Tarif consultation requis';
    }

    if (!RegExp(r'\d').hasMatch(normalized)) {
      return 'Le tarif doit contenir au moins un montant';
    }

    return null;
  }

  List<String> _parseLanguages(String raw) {
    final seen = <String>{};
    final result = <String>[];

    for (final chunk in raw.split(',')) {
      final value = _cleanText(chunk);
      if (value.isEmpty) continue;

      final key = value.toLowerCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      result.add(value);
    }

    return result;
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final controller = ref.read(professionalProfileProvider.notifier);

      await controller.updateProfile(
        displayName: _cleanText(_displayNameCtrl.text),
        specialty: _cleanText(_specialtyCtrl.text),
        structureName: _cleanText(_structureNameCtrl.text),
        phone: _normalizePhone(_phoneCtrl.text),
        city: _cleanText(_cityCtrl.text),
        area: _cleanText(_areaCtrl.text),
        address: _cleanText(_addressCtrl.text),
        bio: _normalizeMultilineText(_bioCtrl.text),
        languages: _parseLanguages(_languagesCtrl.text),
        consultationFeeLabel: _cleanText(_consultationFeeCtrl.text),
        isVerified: _isVerified,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil professionnel mis à jour.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’enregistrer les modifications pour le moment.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final previewLocation = [
      _cleanText(_addressCtrl.text),
      _cleanText(_areaCtrl.text),
      _cleanText(_cityCtrl.text),
    ].where((value) => value.isNotEmpty).join(' • ');

    final previewLanguages = _parseLanguages(_languagesCtrl.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.edit_note_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mettez à jour les informations visibles par les patients dans la recherche et sur votre fiche professionnelle.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Identité professionnelle',
                icon: Icons.badge_outlined,
                children: [
                  TextFormField(
                    controller: _displayNameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché',
                      hintText: 'Ex : Dr Kouamé Aya',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Nom affiché'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specialtyCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité',
                      hintText: 'Ex : Médecin généraliste',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Spécialité'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _structureNameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Structure',
                      hintText: 'Ex : Cabinet Médical Sainte Grâce',
                      prefixIcon: Icon(Icons.local_hospital_outlined),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Structure'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Coordonnées',
                icon: Icons.call_outlined,
                children: [
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      hintText: '+2250700000001',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: _phoneValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      hintText: 'Ex : Abidjan',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: (value) => _requiredValidator(value, 'Ville'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _areaCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Quartier / zone',
                      hintText: 'Ex : Cocody',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (value) => _requiredValidator(value, 'Quartier'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'Ex : Rue des Jardins',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    validator: (value) => _requiredValidator(value, 'Adresse'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Présentation',
                icon: Icons.description_outlined,
                children: [
                  TextFormField(
                    controller: _bioCtrl,
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Biographie',
                      alignLabelWithHint: true,
                      hintText:
                          'Présentez votre pratique, votre expérience, vos domaines de prise en charge...',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                    ),
                    validator: (value) =>
                        _requiredValidator(value, 'Biographie'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Paramètres métier',
                icon: Icons.settings_suggest_outlined,
                children: [
                  TextFormField(
                    controller: _consultationFeeCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tarif consultation',
                      hintText: 'Ex : 10 000 - 15 000 FCFA',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: _consultationFeeValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _languagesCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Langues',
                      hintText: 'Ex : Français, Anglais',
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
                    validator: (value) {
                      final items = _parseLanguages(value ?? '');
                      if (items.isEmpty) {
                        return 'Au moins une langue requise';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isVerified,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Profil vérifié'),
                    subtitle: const Text(
                      'Indicateur visuel affiché sur la fiche professionnelle.',
                    ),
                    onChanged: (value) {
                      setState(() => _isVerified = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aperçu rapide',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _PreviewLine(
                        label: 'Nom',
                        value: _cleanText(_displayNameCtrl.text).isEmpty
                            ? '—'
                            : _cleanText(_displayNameCtrl.text),
                      ),
                      _PreviewLine(
                        label: 'Spécialité',
                        value: _cleanText(_specialtyCtrl.text).isEmpty
                            ? '—'
                            : _cleanText(_specialtyCtrl.text),
                      ),
                      _PreviewLine(
                        label: 'Structure',
                        value: _cleanText(_structureNameCtrl.text).isEmpty
                            ? '—'
                            : _cleanText(_structureNameCtrl.text),
                      ),
                      _PreviewLine(
                        label: 'Lieu',
                        value: previewLocation.isEmpty ? '—' : previewLocation,
                      ),
                      _PreviewLine(
                        label: 'Langues',
                        value: previewLanguages.isEmpty
                            ? '—'
                            : previewLanguages.join(', '),
                      ),
                      _PreviewLine(
                        label: 'Tarif',
                        value: _cleanText(_consultationFeeCtrl.text).isEmpty
                            ? '—'
                            : _cleanText(_consultationFeeCtrl.text),
                      ),
                      _PreviewLine(
                        label: 'Vérification',
                        value: _isVerified ? 'Profil vérifié' : 'Non vérifié',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Enregistrement...' : 'Enregistrer',
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

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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