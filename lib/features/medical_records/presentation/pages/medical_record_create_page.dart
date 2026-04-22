import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/medical_record.dart';
import '../providers/medical_records_providers.dart';

class MedicalRecordCreatePage extends ConsumerStatefulWidget {
  const MedicalRecordCreatePage({super.key});

  @override
  ConsumerState<MedicalRecordCreatePage> createState() =>
      _MedicalRecordCreatePageState();
}

class _MedicalRecordCreatePageState
    extends ConsumerState<MedicalRecordCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  MedicalRecordCategory _category = MedicalRecordCategory.prescription;
  DateTime _recordDate = DateTime.now();
  bool _isSensitive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sourceCtrl.dispose();
    _summaryCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String label) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return '$label requis';
    }
    return null;
  }

  String _normalizePatientId({
    required String rawId,
    required String rawPhone,
  }) {
    final phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isNotEmpty) {
      return phoneDigits;
    }

    final cleanedId = rawId.trim();
    if (cleanedId.isNotEmpty) {
      return cleanedId;
    }

    return 'patient_inconnu';
  }

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _cleanMultilineText(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String? _cleanNullableMultilineText(String value) {
    final cleaned = _cleanMultilineText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _pickRecordDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _recordDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) return;

    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Utilisateur introuvable. Veuillez vous reconnecter.'),
          ),
        );
      return;
    }

    final patientName = user.name.trim().isNotEmpty
        ? user.name.trim()
        : 'Utilisateur';

    final patientId = _normalizePatientId(
      rawId: user.id,
      rawPhone: user.phone,
    );

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final now = DateTime.now();

    final record = MedicalRecord(
      id: 'mr_${now.microsecondsSinceEpoch}',
      patientId: patientId,
      title: _cleanText(_titleCtrl.text),
      category: _category,
      recordDate: DateTime(
        _recordDate.year,
        _recordDate.month,
        _recordDate.day,
      ),
      createdAt: now,
      patientName: patientName,
      sourceLabel: _cleanText(_sourceCtrl.text),
      summary: _cleanMultilineText(_summaryCtrl.text),
      isSensitive: _isSensitive,
      description: _cleanNullableMultilineText(_descriptionCtrl.text),
    );

    try {
      await ref.read(medicalRecordsControllerProvider).create(record);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Document médical créé.'),
          ),
        );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de créer le document médical.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau document médical'),
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
                      Icon(Icons.note_add_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ajoutez un document médical structuré à votre dossier local.',
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
                        'Informations du document',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Titre',
                          hintText: 'Ex : Ordonnance consultation générale',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (value) => _requiredValidator(value, 'Titre'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MedicalRecordCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: MedicalRecordCategory.prescription,
                            child: Text('Ordonnance'),
                          ),
                          DropdownMenuItem(
                            value: MedicalRecordCategory.labResult,
                            child: Text('Analyse'),
                          ),
                          DropdownMenuItem(
                            value: MedicalRecordCategory.imaging,
                            child: Text('Imagerie'),
                          ),
                          DropdownMenuItem(
                            value: MedicalRecordCategory.certificate,
                            child: Text('Certificat'),
                          ),
                          DropdownMenuItem(
                            value: MedicalRecordCategory.report,
                            child: Text('Compte rendu'),
                          ),
                          DropdownMenuItem(
                            value: MedicalRecordCategory.other,
                            child: Text('Autre'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sourceCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Source',
                          hintText: 'Ex : Clinique, laboratoire, cabinet...',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        validator: (value) =>
                            _requiredValidator(value, 'Source'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickRecordDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          'Date du document : ${_formatDate(_recordDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _summaryCtrl,
                        minLines: 3,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Résumé',
                          alignLabelWithHint: true,
                          hintText:
                              'Résumé court du contenu principal du document...',
                          prefixIcon: Icon(Icons.summarize_outlined),
                        ),
                        validator: (value) =>
                            _requiredValidator(value, 'Résumé'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionCtrl,
                        minLines: 4,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Description détaillée (optionnelle)',
                          alignLabelWithHint: true,
                          hintText:
                              'Ajoutez des précisions complémentaires sur le document...',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _isSensitive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Document sensible'),
                        subtitle: const Text(
                          'Activez si ce document contient des données médicales sensibles.',
                        ),
                        onChanged: (value) {
                          setState(() => _isSensitive = value);
                        },
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
                    _isSaving ? 'Enregistrement...' : 'Créer le document',
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
