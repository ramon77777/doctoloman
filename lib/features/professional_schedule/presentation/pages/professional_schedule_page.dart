import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../domain/professional_schedule.dart';
import '../providers/professional_schedule_providers.dart';

class ProfessionalSchedulePage extends ConsumerWidget {
  const ProfessionalSchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(professionalProfileProvider);
    final practitionerId = profile.id;
    final schedule = ref.watch(practitionerScheduleProvider(practitionerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilités professionnelles'),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser',
            onPressed: () async {
              await ref
                  .read(professionalSchedulesMapProvider.notifier)
                  .resetDefaults(practitionerId);

              if (!context.mounted) return;

              final messenger = ScaffoldMessenger.of(context);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Horaires réinitialisés.'),
                  ),
                );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Définissez les jours ouverts et les plages de consultation. '
                  'Cette base servira ensuite à relier les créneaux côté patient.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...schedule.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayScheduleCard(
                  practitionerId: practitionerId,
                  day: day,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayScheduleCard extends ConsumerWidget {
  const _DayScheduleCard({
    required this.practitionerId,
    required this.day,
  });

  final String practitionerId;
  final DaySchedule day;

  Future<void> _editRange(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String? initialStart,
    required String? initialEnd,
    required bool isMorning,
    required Future<void> Function(String start, String end) onSave,
    required Future<void> Function() onClear,
  }) async {
    final startCtrl = TextEditingController(text: initialStart ?? '');
    final endCtrl = TextEditingController(text: initialEnd ?? '');
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await showDialog<_TimeRangeAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: startCtrl,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Début',
                      hintText: '08:30',
                    ),
                    validator: _validateHour,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endCtrl,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Fin',
                      hintText: '12:00',
                    ),
                    validator: _validateHour,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_TimeRangeAction.cancel),
                child: const Text('Fermer'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_TimeRangeAction.clear),
                child: const Text('Effacer'),
              ),
              FilledButton(
                onPressed: () {
                  final ok = formKey.currentState?.validate() ?? false;
                  if (!ok) return;
                  Navigator.of(ctx).pop(_TimeRangeAction.save);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );

      if (result == _TimeRangeAction.clear) {
        await onClear();

        if (!context.mounted) return;

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$title effacé.'),
            ),
          );
        return;
      }

      if (result != _TimeRangeAction.save) return;

      final start = startCtrl.text.trim();
      final end = endCtrl.text.trim();

      final validationError = _validateTimeRange(
        start: start,
        end: end,
        otherStart: isMorning ? day.afternoonStart : day.morningStart,
        otherEnd: isMorning ? day.afternoonEnd : day.morningEnd,
        isMorning: isMorning,
      );

      if (validationError != null) {
        if (!context.mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(validationError)),
          );
        return;
      }

      await onSave(start, end);

      if (!context.mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$title mis à jour.'),
          ),
        );
    } finally {
      startCtrl.dispose();
      endCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = ref.read(professionalSchedulesMapProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: day.isOpen,
                  onChanged: (value) async {
                    await controller.toggleDay(
                      practitionerId,
                      day.weekday,
                      value,
                    );
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                day.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (day.isOpen) ...[
              const SizedBox(height: 14),
              _RangeTile(
                label: 'Matin',
                value: day.morningLabel,
                onTap: () => _editRange(
                  context,
                  ref,
                  title: '${day.label} • Matin',
                  initialStart: day.morningStart,
                  initialEnd: day.morningEnd,
                  isMorning: true,
                  onSave: (start, end) {
                    return controller.updateMorning(
                      practitionerId: practitionerId,
                      weekday: day.weekday,
                      start: start,
                      end: end,
                    );
                  },
                  onClear: () {
                    return controller.clearMorning(
                      practitionerId,
                      day.weekday,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _RangeTile(
                label: 'Après-midi',
                value: day.afternoonLabel,
                onTap: () => _editRange(
                  context,
                  ref,
                  title: '${day.label} • Après-midi',
                  initialStart: day.afternoonStart,
                  initialEnd: day.afternoonEnd,
                  isMorning: false,
                  onSave: (start, end) {
                    return controller.updateAfternoon(
                      practitionerId: practitionerId,
                      weekday: day.weekday,
                      start: start,
                      end: end,
                    );
                  },
                  onClear: () {
                    return controller.clearAfternoon(
                      practitionerId,
                      day.weekday,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RangeTile extends StatelessWidget {
  const _RangeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(value),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined),
          ],
        ),
      ),
    );
  }
}

enum _TimeRangeAction { cancel, clear, save }

String? _validateHour(String? value) {
  final v = (value ?? '').trim();
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(v)) {
    return 'Format attendu : HH:MM';
  }

  final parts = v.split(':');
  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) {
    return 'Heure invalide';
  }
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
    return 'Heure invalide';
  }

  return null;
}

int? _toMinutes(String hhmm) {
  final value = hhmm.trim();
  if (value.isEmpty) return null;

  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;

  return hh * 60 + mm;
}

String? _validateTimeRange({
  required String start,
  required String end,
  required String? otherStart,
  required String? otherEnd,
  required bool isMorning,
}) {
  final startMinutes = _toMinutes(start);
  final endMinutes = _toMinutes(end);

  if (startMinutes == null || endMinutes == null) {
    return 'Heure invalide.';
  }

  if (startMinutes >= endMinutes) {
    return 'L’heure de début doit être avant l’heure de fin.';
  }

  final otherStartMinutes = _toMinutes(otherStart ?? '');
  final otherEndMinutes = _toMinutes(otherEnd ?? '');

  if (otherStartMinutes != null && otherEndMinutes != null) {
    final overlaps =
        startMinutes < otherEndMinutes && endMinutes > otherStartMinutes;

    if (overlaps) {
      return 'Cette plage chevauche l’autre plage horaire de la journée.';
    }

    if (isMorning && endMinutes > otherStartMinutes) {
      return 'La plage du matin doit se terminer avant celle de l’après-midi.';
    }

    if (!isMorning && startMinutes < otherEndMinutes) {
      return 'La plage de l’après-midi doit commencer après celle du matin.';
    }
  }

  return null;
}