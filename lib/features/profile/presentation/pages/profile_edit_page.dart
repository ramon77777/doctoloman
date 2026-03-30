import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/string_normalizers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/patient_profile.dart';
import '../providers/patient_profile_providers.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  DateTime? _birthDate;
  PatientGender? _gender;
  bool _initialized = false;
  bool _isSaving = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final authUser = ref.read(authControllerProvider).user;
    final profile = ref.read(patientProfileProvider).valueOrNull;

    _nameCtrl.text = profile?.name ?? authUser?.name ?? '';
    _phoneCtrl.text = profile?.phone ?? authUser?.phone ?? '';
    _cityCtrl.text = profile?.city ?? '';
    _districtCtrl.text = profile?.district ?? '';
    _addressCtrl.text = profile?.address ?? '';
    _bloodGroupCtrl.text = profile?.bloodGroup ?? '';
    _allergiesCtrl.text = profile?.allergies ?? '';
    _medicalNotesCtrl.text = profile?.medicalNotes ?? '';
    _emergencyNameCtrl.text = profile?.emergencyContactName ?? '';
    _emergencyPhoneCtrl.text = profile?.emergencyContactPhone ?? '';
    _birthDate = profile?.birthDate;
    _gender = profile?.gender;

    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _addressCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicalNotesCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    final normalized = StringNormalizers.collapseSpaces(value ?? '');
    if (normalized.isEmpty) return 'Nom requis';
    if (normalized.length < 2) return 'Nom trop court';
    return null;
  }

  String? _phoneValidator(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) return 'Téléphone requis';
    if (!StringNormalizers.isValidCiPhone(raw)) {
      return 'Format attendu : +225XXXXXXXXXX';
    }
    return null;
  }

  String? _requiredTextValidator(String? value, String label) {
    final normalized = StringNormalizers.collapseSpaces(value ?? '');
    if (normalized.isEmpty) return '$label requis';
    return null;
  }

  String? _optionalPhoneValidator(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) return null;
    if (!StringNormalizers.isValidCiPhone(raw)) {
      return 'Format attendu : +225XXXXXXXXXX';
    }
    return null;
  }

  String? _bloodGroupValidator(String? value) {
    final raw = StringNormalizers.collapseSpaces(value ?? '');
    if (raw.isEmpty) return null;

    const allowed = {
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
    };

    if (!allowed.contains(raw.toUpperCase())) {
      return 'Exemples : O+, A-, AB+';
    }
    return null;
  }

  String? _genderValidator(PatientGender? value) {
    if (value == null) return 'Sexe requis';
    return null;
  }

  String? _birthDateValidator(DateTime? value) {
    if (value == null) return 'Date de naissance requise';
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }

    final authUser = ref.read(authControllerProvider).user;
    if (authUser == null) {
      _showMessage('Vous devez être connecté pour modifier votre profil.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final normalizedName = StringNormalizers.collapseSpaces(_nameCtrl.text);
      final normalizedPhone = StringNormalizers.normalizePhoneCi(_phoneCtrl.text);
      final normalizedBloodGroup =
          StringNormalizers.collapseSpaces(_bloodGroupCtrl.text).toUpperCase();

      await ref.read(authControllerProvider.notifier).updateProfile(
            name: normalizedName,
            phone: normalizedPhone,
          );

      final updatedAuthUser = ref.read(authControllerProvider).user ?? authUser;

      final profile = PatientProfile(
        id: updatedAuthUser.id,
        name: normalizedName,
        phone: normalizedPhone,
        city: _nullIfBlank(_cityCtrl.text),
        district: _nullIfBlank(_districtCtrl.text),
        address: _nullIfBlank(_addressCtrl.text),
        birthDate: _birthDate,
        gender: _gender,
        bloodGroup: normalizedBloodGroup.isEmpty ? null : normalizedBloodGroup,
        allergies: _nullIfBlank(_allergiesCtrl.text),
        medicalNotes: _nullIfBlank(_medicalNotesCtrl.text),
        emergencyContactName: _nullIfBlank(_emergencyNameCtrl.text),
        emergencyContactPhone: _normalizeOptionalPhone(_emergencyPhoneCtrl.text),
      );

      await ref.read(patientProfileControllerProvider).save(profile);

      if (!mounted) return;
      _showMessage('Profil mis à jour.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible d’enregistrer les modifications.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _nullIfBlank(String value) {
    final normalized = StringNormalizers.collapseSpaces(value);
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizeOptionalPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return StringNormalizers.normalizePhoneCi(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (authState.user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier mon profil'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté pour modifier votre profil.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.edit_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Complétez vos informations patient pour améliorer la prise en charge et faciliter les contacts en cas de besoin.',
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
                title: 'Informations principales',
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      hintText: 'Ex : Konan Awa',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _nameValidator,
                  ),
                  const SizedBox(height: 12),
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
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      hintText: 'Ex : Abidjan',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: (value) => _requiredTextValidator(value, 'Ville'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _districtCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Commune / quartier',
                      hintText: 'Ex : Cocody',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'Rue, résidence, repère...',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PatientGender>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Sexe',
                      prefixIcon: Icon(Icons.wc_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PatientGender.female,
                        child: Text('Féminin'),
                      ),
                      DropdownMenuItem(
                        value: PatientGender.male,
                        child: Text('Masculin'),
                      ),
                      DropdownMenuItem(
                        value: PatientGender.other,
                        child: Text('Autre'),
                      ),
                    ],
                    validator: _genderValidator,
                    onChanged: (value) {
                      setState(() => _gender = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  FormField<DateTime>(
                    initialValue: _birthDate,
                    validator: (_) => _birthDateValidator(_birthDate),
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _pickBirthDate();
                              field.didChange(_birthDate);
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _birthDate == null
                                  ? 'Ajouter la date de naissance'
                                  : 'Date de naissance : ${_formatDate(_birthDate!)}',
                            ),
                          ),
                          if (field.hasError) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Informations médicales utiles',
                children: [
                  TextFormField(
                    controller: _bloodGroupCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Groupe sanguin',
                      hintText: 'Ex : O+, A-, AB+',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    validator: _bloodGroupValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _allergiesCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      hintText: 'Ex : pénicilline, arachide...',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _medicalNotesCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes médicales',
                      hintText: 'Antécédents, informations utiles...',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.medical_information_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Contact d’urgence',
                children: [
                  TextFormField(
                    controller: _emergencyNameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom du contact',
                      hintText: 'Ex : Konan Koffi',
                      prefixIcon: Icon(Icons.contact_phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone du contact',
                      hintText: '+2250700000002',
                      prefixIcon: Icon(Icons.phone_callback_outlined),
                    ),
                    validator: _optionalPhoneValidator,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
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
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...children,
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