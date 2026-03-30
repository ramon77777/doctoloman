import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/string_normalizers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    final user = ref.read(authControllerProvider).user;
    _nameCtrl.text = user?.name ?? '';
    _phoneCtrl.text = user?.phone ?? '';

    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    final normalized = StringNormalizers.collapseSpaces(value ?? '');
    if (normalized.isEmpty) {
      return 'Nom requis';
    }
    if (normalized.length < 2) {
      return 'Nom trop court';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) {
      return 'Téléphone requis';
    }
    if (!StringNormalizers.isValidCiPhone(raw)) {
      return 'Format attendu : +225XXXXXXXXXX';
    }
    return null;
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) return;

    final authState = ref.read(authControllerProvider);
    if (authState.user == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
          );

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’enregistrer les modifications.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

    final normalizedPreviewName =
        StringNormalizers.collapseSpaces(_nameCtrl.text).trim();
    final normalizedPreviewPhone =
        StringNormalizers.normalizePhoneCi(_phoneCtrl.text).trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
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
                      Icon(Icons.edit_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mettez à jour les informations principales de votre compte patient.',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations personnelles',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
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
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          hintText: '+2250700000001',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: _phoneValidator,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aperçu',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _PreviewLine(
                        label: 'Nom',
                        value: normalizedPreviewName.isEmpty
                            ? '—'
                            : normalizedPreviewName,
                      ),
                      _PreviewLine(
                        label: 'Téléphone',
                        value: normalizedPreviewPhone.isEmpty
                            ? '—'
                            : normalizedPreviewPhone,
                      ),
                    ],
                  ),
                ),
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

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
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