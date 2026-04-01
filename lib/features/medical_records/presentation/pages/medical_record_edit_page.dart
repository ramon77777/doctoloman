import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/medical_record.dart';
import '../providers/medical_records_providers.dart';

class MedicalRecordEditPage extends ConsumerStatefulWidget {
  const MedicalRecordEditPage({
    super.key,
    required this.recordId,
  });

  final String recordId;

  @override
  ConsumerState<MedicalRecordEditPage> createState() =>
      _MedicalRecordEditPageState();
}

class _MedicalRecordEditPageState
    extends ConsumerState<MedicalRecordEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  MedicalRecordCategory _category = MedicalRecordCategory.prescription;
  DateTime _recordDate = DateTime.now();
  bool _isSensitive = true;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sourceCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String label) {
    final normalized = _cleanText(value ?? '');
    if (normalized.isEmpty) {
      return '$label requis';
    }
    return null;
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

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _hydrate(MedicalRecord record) {
    if (_initialized) return;

    _titleCtrl.text = record.title;
    _sourceCtrl.text = record.sourceLabel;
    _summaryCtrl.text = record.summary;
    _category = record.category;
    _recordDate = DateTime(
      record.recordDate.year,
      record.recordDate.month,
      record.recordDate.day,
    );
    _isSensitive = record.isSensitive;
    _initialized = true;
  }

  Future<void> _pickRecordDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _recordDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save(MedicalRecord current) async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final cleanedTitle = _cleanText(_titleCtrl.text);
    final cleanedSource = _cleanText(_sourceCtrl.text);
    final cleanedSummary = _cleanMultilineText(_summaryCtrl.text);

    final updated = current.copyWith(
      title: cleanedTitle,
      category: _category,
      recordDate: DateTime(
        _recordDate.year,
        _recordDate.month,
        _recordDate.day,
      ),
      sourceLabel: cleanedSource,
      summary: cleanedSummary,
      isSensitive: _isSensitive,
      description: cleanedSummary,
    );

    try {
      await ref.read(medicalRecordsControllerProvider).update(updated);

      if (!mounted) return;
      setState(() => _isSaving = false);

      _showMessage('Document médical mis à jour.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      _showMessage('Impossible de mettre à jour le document.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedId = widget.recordId.trim();

    if (normalizedId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier le document'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Document introuvable.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final recordAsync = ref.watch(medicalRecordByIdProvider(normalizedId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le document'),
      ),
      body: SafeArea(
        child: recordAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (record) {
            if (record == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Document introuvable.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            _hydrate(record);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
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
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      prefixIcon: Icon(Icons.local_hospital_outlined),
                    ),
                    validator: (value) => _requiredValidator(value, 'Source'),
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
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Résumé / description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    validator: (value) => _requiredValidator(value, 'Résumé'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isSensitive,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Document sensible'),
                    subtitle: const Text(
                      'Activez si ce document contient des données sensibles.',
                    ),
                    onChanged: (value) {
                      setState(() => _isSensitive = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : () => _save(record),
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement...'
                            : 'Enregistrer les modifications',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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