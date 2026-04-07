import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../domain/professional_schedule.dart';
import '../providers/professional_schedule_providers.dart';

class ProfessionalSchedulePage extends ConsumerStatefulWidget {
  const ProfessionalSchedulePage({super.key});

  @override
  ConsumerState<ProfessionalSchedulePage> createState() =>
      _ProfessionalSchedulePageState();
}

class _ProfessionalSchedulePageState
    extends ConsumerState<ProfessionalSchedulePage> {
  int _selectedWeekday = 1;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(professionalProfileProvider);
    final practitionerId = profile.id;
    final schedule = ref.watch(practitionerScheduleProvider(practitionerId));

    final selectedDay = schedule.firstWhere(
      (day) => day.weekday == _selectedWeekday,
      orElse: () => schedule.first,
    );

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

              final refreshedSchedule =
                  ref.read(practitionerScheduleProvider(practitionerId));

              setState(() {
                _selectedWeekday = refreshedSchedule.first.weekday;
              });

              final messenger = ScaffoldMessenger.of(context);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Créneaux réinitialisés.'),
                  ),
                );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: selectedDay.isOpen
          ? FloatingActionButton.extended(
              onPressed: () => _showSlotEditor(
                context,
                practitionerId: practitionerId,
                weekday: selectedDay.weekday,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un créneau'),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Sélectionnez un jour puis définissez librement les créneaux de consultation. '
                  'Vous pouvez saisir des créneaux personnalisés comme 08:10 - 08:18 ou 08:20 - 08:35.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _WeekdayTabs(
              days: schedule,
              selectedWeekday: selectedDay.weekday,
              onSelected: (weekday) {
                setState(() => _selectedWeekday = weekday);
              },
            ),
            const SizedBox(height: 14),
            _SelectedDayCard(
              practitionerId: practitionerId,
              day: selectedDay,
              onAddSlot: () => _showSlotEditor(
                context,
                practitionerId: practitionerId,
                weekday: selectedDay.weekday,
              ),
              onEditSlot: (index, slot) => _showSlotEditor(
                context,
                practitionerId: practitionerId,
                weekday: selectedDay.weekday,
                slotIndex: index,
                initialSlot: slot,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSlotEditor(
    BuildContext context, {
    required String practitionerId,
    required int weekday,
    int? slotIndex,
    TimeSlot? initialSlot,
  }) async {
    final isEditing = slotIndex != null && initialSlot != null;

    final startCtrl = TextEditingController(text: initialSlot?.start ?? '');
    final endCtrl = TextEditingController(text: initialSlot?.end ?? '');
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(professionalSchedulesMapProvider.notifier);

    try {
      final result = await showDialog<_SlotEditorAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              isEditing ? 'Modifier le créneau' : 'Ajouter un créneau',
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: startCtrl,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Début',
                      hintText: '08:10',
                    ),
                    validator: _validateHour,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endCtrl,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Fin',
                      hintText: '08:18',
                    ),
                    validator: _validateHour,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_SlotEditorAction.cancel),
                child: const Text('Fermer'),
              ),
              if (isEditing)
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_SlotEditorAction.delete),
                  child: const Text('Supprimer'),
                ),
              FilledButton(
                onPressed: () {
                  final ok = formKey.currentState?.validate() ?? false;
                  if (!ok) return;
                  Navigator.of(ctx).pop(_SlotEditorAction.save);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );

      if (result == _SlotEditorAction.delete && isEditing) {
        await controller.removeSlot(
          practitionerId: practitionerId,
          weekday: weekday,
          slotIndex: slotIndex,
        );

        if (!context.mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Créneau supprimé.')),
          );
        return;
      }

      if (result != _SlotEditorAction.save) return;

      final normalizedSlot = TimeSlot(
        start: _normalizeHour(startCtrl.text),
        end: _normalizeHour(endCtrl.text),
      );

      final refreshedDay =
          ref.read(practitionerScheduleProvider(practitionerId)).firstWhere(
                (day) => day.weekday == weekday,
              );

      final validationError = _validateSlotAgainstDay(
        slot: normalizedSlot,
        existingSlots: refreshedDay.slots,
        editingIndex: slotIndex,
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

      if (isEditing) {
        await controller.updateSlot(
          practitionerId: practitionerId,
          weekday: weekday,
          slotIndex: slotIndex,
          slot: normalizedSlot,
        );
      } else {
        await controller.addSlot(
          practitionerId: practitionerId,
          weekday: weekday,
          slot: normalizedSlot,
        );
      }

      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Créneau mis à jour.' : 'Créneau ajouté.',
            ),
          ),
        );
    } finally {
      startCtrl.dispose();
      endCtrl.dispose();
    }
  }
}

class _WeekdayTabs extends StatelessWidget {
  const _WeekdayTabs({
    required this.days,
    required this.selectedWeekday,
    required this.onSelected,
  });

  final List<DaySchedule> days;
  final int selectedWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.weekday == selectedWeekday;
          final cs = Theme.of(context).colorScheme;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(day.weekday),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Center(
                child: Text(
                  day.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedDayCard extends ConsumerWidget {
  const _SelectedDayCard({
    required this.practitionerId,
    required this.day,
    required this.onAddSlot,
    required this.onEditSlot,
  });

  final String practitionerId;
  final DaySchedule day;
  final VoidCallback onAddSlot;
  final void Function(int index, TimeSlot slot) onEditSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(professionalSchedulesMapProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              day.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (!day.isOpen) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Ce jour est fermé. Activez-le pour ajouter des créneaux.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              if (day.slots.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Aucun créneau défini pour ce jour.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                )
              else
                ...day.slots.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final slot = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SlotTile(
                        slot: slot,
                        onEdit: () => onEditSlot(index, slot),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: onAddSlot,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un créneau'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.onEdit,
  });

  final TimeSlot slot;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                slot.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Icon(Icons.edit_outlined),
          ],
        ),
      ),
    );
  }
}

enum _SlotEditorAction { cancel, delete, save }

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

String _normalizeHour(String value) {
  final trimmed = value.trim();
  final parts = trimmed.split(':');

  if (parts.length != 2) {
    return trimmed;
  }

  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);

  if (hh == null || mm == null) {
    return trimmed;
  }

  return '${hh.clamp(0, 23).toString().padLeft(2, '0')}:${mm.clamp(0, 59).toString().padLeft(2, '0')}';
}

String? _validateSlotAgainstDay({
  required TimeSlot slot,
  required List<TimeSlot> existingSlots,
  int? editingIndex,
}) {
  final startMinutes = toMinutes(slot.start);
  final endMinutes = toMinutes(slot.end);

  if (startMinutes == null || endMinutes == null) {
    return 'Heure invalide.';
  }

  if (startMinutes >= endMinutes) {
    return 'L’heure de début doit être avant l’heure de fin.';
  }

  for (var i = 0; i < existingSlots.length; i++) {
    if (editingIndex != null && i == editingIndex) {
      continue;
    }

    final other = existingSlots[i];
    final otherStart = toMinutes(other.start);
    final otherEnd = toMinutes(other.end);

    if (otherStart == null || otherEnd == null) {
      continue;
    }

    final overlaps = startMinutes < otherEnd && endMinutes > otherStart;
    if (overlaps) {
      return 'Ce créneau chevauche un créneau existant.';
    }
  }

  return null;
}