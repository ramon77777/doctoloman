import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
    final authState = ref.watch(authControllerProvider);

    if (!authState.isAuthenticated || !authState.isProfessional) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Disponibilités professionnelles'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous devez être connecté avec un compte professionnel pour accéder à cette page.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final profile = ref.watch(professionalProfileProvider);
    final practitionerId = profile.id.trim().isNotEmpty
        ? profile.id.trim()
        : _fallbackPractitionerId(authState.user);

    final schedule = ref.watch(practitionerScheduleProvider(practitionerId));

    if (schedule.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Disponibilités professionnelles'),
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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

              if (!mounted) return;

              final refreshedSchedule =
                  ref.read(practitionerScheduleProvider(practitionerId));

              if (refreshedSchedule.isNotEmpty) {
                setState(() {
                  _selectedWeekday = refreshedSchedule.first.weekday;
                });
              }

              _showMessage('Créneaux réinitialisés.');
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: selectedDay.isOpen
          ? FloatingActionButton.extended(
              onPressed: () => _showSlotEditor(
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
                  'Les créneaux configurés ici seront affichés tels quels côté patient.',
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
                practitionerId: practitionerId,
                weekday: selectedDay.weekday,
              ),
              onEditSlot: (index, slot) => _showSlotEditor(
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

  Future<void> _showSlotEditor({
    required String practitionerId,
    required int weekday,
    int? slotIndex,
    TimeSlot? initialSlot,
  }) async {
    final isEditing = slotIndex != null && initialSlot != null;

    final currentDay =
        ref.read(practitionerScheduleProvider(practitionerId)).firstWhere(
              (day) => day.weekday == weekday,
              orElse: () => DaySchedule(
                weekday: weekday,
                label: 'Jour',
                isOpen: true,
                slots: const [],
              ),
            );

    final result = await showDialog<_SlotEditorResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SlotEditorDialog(
          isEditing: isEditing,
          initialSlot: initialSlot,
          existingSlots: currentDay.slots,
          editingIndex: slotIndex,
        );
      },
    );

    if (!mounted || result == null) return;

    final controller = ref.read(professionalSchedulesMapProvider.notifier);

    switch (result.action) {
      case _SlotEditorAction.cancel:
        return;

      case _SlotEditorAction.delete:
        if (!isEditing) return;

        await controller.removeSlot(
          practitionerId: practitionerId,
          weekday: weekday,
          slotIndex: slotIndex,
        );

        if (!mounted) return;

        setState(() {
          _selectedWeekday = weekday;
        });

        _showMessage('Créneau supprimé.');
        return;

      case _SlotEditorAction.save:
        final slot = result.slot;
        if (slot == null) {
          _showMessage('Créneau invalide.');
          return;
        }

        if (isEditing) {
          await controller.updateSlot(
            practitionerId: practitionerId,
            weekday: weekday,
            slotIndex: slotIndex,
            slot: slot,
          );
        } else {
          await controller.addSlot(
            practitionerId: practitionerId,
            weekday: weekday,
            slot: slot,
          );
        }

        if (!mounted) return;

        setState(() {
          _selectedWeekday = weekday;
        });

        _showMessage(isEditing ? 'Créneau mis à jour.' : 'Créneau ajouté.');
        return;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _fallbackPractitionerId(AppUser? user) {
    final id = user?.id.trim() ?? '';
    if (id.isNotEmpty) {
      return id;
    }

    final digits = (user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      return 'pro-$digits';
    }

    return 'pro-local';
  }
}

class _SlotEditorDialog extends StatefulWidget {
  const _SlotEditorDialog({
    required this.isEditing,
    required this.initialSlot,
    required this.existingSlots,
    required this.editingIndex,
  });

  final bool isEditing;
  final TimeSlot? initialSlot;
  final List<TimeSlot> existingSlots;
  final int? editingIndex;

  @override
  State<_SlotEditorDialog> createState() => _SlotEditorDialogState();
}

class _SlotEditorDialogState extends State<_SlotEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();

    _startCtrl = TextEditingController(
      text: widget.initialSlot?.start ?? '',
    );
    _endCtrl = TextEditingController(
      text: widget.initialSlot?.end ?? '',
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _close(_SlotEditorResult result) {
    Navigator.of(context).pop(result);
  }

  void _save() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final slot = TimeSlot(
      start: _normalizeHour(_startCtrl.text),
      end: _normalizeHour(_endCtrl.text),
    );

    final validationError = _validateSlotAgainstDay(
      slot: slot,
      existingSlots: widget.existingSlots,
      editingIndex: widget.editingIndex,
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      return;
    }

    _close(
      _SlotEditorResult(
        action: _SlotEditorAction.save,
        slot: slot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEditing ? 'Modifier le créneau' : 'Ajouter un créneau',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _startCtrl,
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
              controller: _endCtrl,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Fin',
                hintText: '08:18',
              ),
              validator: _validateHour,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(
            const _SlotEditorResult(action: _SlotEditorAction.cancel),
          ),
          child: const Text('Fermer'),
        ),
        if (widget.isEditing)
          TextButton(
            onPressed: () => _close(
              const _SlotEditorResult(action: _SlotEditorAction.delete),
            ),
            child: const Text('Supprimer'),
          ),
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
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

class _SlotEditorResult {
  const _SlotEditorResult({
    required this.action,
    this.slot,
  });

  final _SlotEditorAction action;
  final TimeSlot? slot;
}

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