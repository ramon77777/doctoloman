import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../appointments/presentation/pages/appointment_flow_page.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/pages/login_phone_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../../professional_schedule/domain/professional_schedule.dart';
import '../../../professional_schedule/domain/slot_generation.dart';
import '../../../professional_schedule/presentation/providers/professional_schedule_providers.dart';
import '../../domain/practitioner_search_resolver.dart';
import '../../domain/search_item.dart';

class PractitionerDetailPage extends ConsumerStatefulWidget {
  const PractitionerDetailPage({
    super.key,
    required this.item,
  });

  final SearchItem item;

  @override
  ConsumerState<PractitionerDetailPage> createState() =>
      _PractitionerDetailPageState();
}

class _PractitionerDetailPageState
    extends ConsumerState<PractitionerDetailPage> {
  late DateTime _selectedDay;
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDay(DateTime.now());
  }

  DateTime _normalizeDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _slotToDateTime(DateTime day, String slot) {
    final parts = slot.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool _isSlotStillBookable(DateTime day, String slot) {
    final slotDateTime = _slotToDateTime(day, slot);
    if (slotDateTime == null) return false;
    return slotDateTime.isAfter(DateTime.now());
  }

  DaySchedule? _scheduleForSelectedDay(List<DaySchedule> schedules) {
    for (final day in schedules) {
      if (day.weekday == _selectedDay.weekday) {
        return day;
      }
    }
    return null;
  }

  List<String> _buildAvailableSlots({
    required List<String> rawSlots,
    required Set<String> takenSlots,
    required DateTime selectedDay,
  }) {
    return rawSlots.where((slot) {
      if (takenSlots.contains(slot)) return false;
      return _isSlotStillBookable(selectedDay, slot);
    }).toList();
  }

  void _pickDay(DateTime day) {
    setState(() {
      _selectedDay = _normalizeDay(day);
      _selectedSlot = null;
    });
  }

  void _pickSlot(String slot) {
    setState(() {
      _selectedSlot = slot;
    });
  }

  void _clearSelectedSlot() {
    setState(() {
      _selectedSlot = null;
    });
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Future<bool> _requireAuth() async {
    final authState = ref.read(authControllerProvider);
    if (authState.isAuthenticated) {
      return true;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginPhonePage(isSignup: false),
      ),
    );

    if (!mounted) return false;

    final updatedAuthState = ref.read(authControllerProvider);
    return result == true || updatedAuthState.isAuthenticated;
  }

  Future<void> _onBook(SearchItem item) async {
    final selectedSlot = _selectedSlot;
    if (selectedSlot == null) {
      _showMessage('Choisis un créneau avant de continuer.');
      return;
    }

    final day = _normalizeDay(_selectedDay);

    if (!_isSlotStillBookable(day, selectedSlot)) {
      _showMessage('Ce créneau n’est plus réservable. Choisis-en un autre.');
      _clearSelectedSlot();
      return;
    }

    final isLoggedIn = ref.read(authControllerProvider).isAuthenticated;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentFlowPage(
          item: item,
          day: day,
          slot: selectedSlot,
          isLoggedIn: isLoggedIn,
          onRequireAuth: _requireAuth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final professionalProfile = ref.watch(professionalProfileProvider);

    final resolved = resolvePractitionerData(
      baseItem: widget.item,
      profile: professionalProfile,
    );

    final practitionerId = resolved.item.id;
    final selectedDay = _normalizeDay(_selectedDay);

    final schedules = ref.watch(practitionerScheduleProvider(practitionerId));
    final schedule = _scheduleForSelectedDay(schedules);

    final rawSlotResult = schedule == null
        ? const SlotGenerationResult(
            isOpen: false,
            slots: [],
          )
        : buildSlotsForDay(
            schedule: schedule,
            selectedDay: selectedDay,
          );

    final takenSlotsAsync = ref.watch(
      takenSlotsForPractitionerDayProvider(
        TakenSlotsQuery(
          practitionerId: practitionerId,
          day: selectedDay,
        ),
      ),
    );

    final bottomInset = MediaQuery.of(context).padding.bottom;
    const actionHeight = 50.0;
    const actionPadding = 22.0;
    final reservedBottomSpace =
        bottomInset + actionHeight + actionPadding + 18;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.background,
            surfaceTintColor: AppColors.background,
            title: Text(
              resolved.item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PractitionerHeader(item: resolved.item),
                  const SizedBox(height: 12),
                  const _SectionTitle(title: 'Informations'),
                  const SizedBox(height: 10),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.local_hospital_outlined,
                        title: 'Structure',
                        value: resolved.structureName,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        title: 'Adresse',
                        value: resolved.addressLabel,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        title: 'Tarif',
                        value: resolved.item.priceLabel,
                      ),
                      if (resolved.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.call_outlined,
                          title: 'Téléphone',
                          value: resolved.phone,
                        ),
                      ],
                      const SizedBox(height: 10),
                      const _InfoRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Données',
                        value: 'Hébergement local • Accès sous consentement',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Choisir un créneau'),
                  const SizedBox(height: 10),
                  _DayPicker(
                    selected: selectedDay,
                    onSelect: _pickDay,
                  ),
                  const SizedBox(height: 12),
                  if (schedule != null) ...[
                    _ScheduleSummaryCard(
                      label: schedule.label,
                      summary: schedule.summary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  takenSlotsAsync.when(
                    loading: () => const _LoadingAvailabilityCard(),
                    error: (error, _) => _AvailabilityMessageCard(
                      icon: Icons.error_outline,
                      title: 'Impossible de charger les disponibilités',
                      message: '$error',
                    ),
                    data: (takenSlots) {
                      final availableSlots = _buildAvailableSlots(
                        rawSlots: rawSlotResult.slots,
                        takenSlots: takenSlots,
                        selectedDay: selectedDay,
                      );

                      final isOpenSelectedDay = rawSlotResult.isOpen;
                      final isLoggedIn = authState.isAuthenticated;
                      final canBook = _selectedSlot != null &&
                          availableSlots.contains(_selectedSlot);

                      if (!isOpenSelectedDay) {
                        return const _AvailabilityMessageCard(
                          icon: Icons.event_busy_outlined,
                          title: 'Cabinet fermé ce jour',
                          message:
                              'Ce professionnel n’ouvre pas ce jour-là. Choisis une autre date.',
                        );
                      }

                      if (availableSlots.isEmpty) {
                        final isToday = _isSameDay(
                          selectedDay,
                          _normalizeDay(DateTime.now()),
                        );

                        return _AvailabilityMessageCard(
                          icon: Icons.schedule_outlined,
                          title: 'Aucun créneau disponible',
                          message: isToday
                              ? 'Il ne reste plus de créneau réservable aujourd’hui. Choisis une autre date.'
                              : 'Tous les créneaux de cette date sont déjà pris ou indisponibles.',
                        );
                      }

                      return _BookingSection(
                        availableSlots: availableSlots,
                        selectedSlot: _selectedSlot,
                        isLoggedIn: isLoggedIn,
                        onSelectSlot: _pickSlot,
                        onBook: canBook ? () => _onBook(resolved.item) : null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'À propos'),
                  const SizedBox(height: 10),
                  _AboutCard(data: resolved),
                  SizedBox(height: reservedBottomSpace),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSection extends StatelessWidget {
  const _BookingSection({
    required this.availableSlots,
    required this.selectedSlot,
    required this.isLoggedIn,
    required this.onSelectSlot,
    required this.onBook,
  });

  final List<String> availableSlots;
  final String? selectedSlot;
  final bool isLoggedIn;
  final void Function(String slot) onSelectSlot;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SlotsGrid(
          slots: availableSlots,
          selectedSlot: selectedSlot,
          onSelect: onSelectSlot,
        ),
        const SizedBox(height: 10),
        Text(
          '${availableSlots.length} créneau(x) disponible(s)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: onBook,
            icon: const Icon(Icons.event_available),
            label: Text(
              selectedSlot != null
                  ? (isLoggedIn
                      ? 'Envoyer la demande'
                      : 'Se connecter pour continuer')
                  : 'Choisis un créneau',
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _PractitionerHeader extends StatelessWidget {
  const _PractitionerHeader({required this.item});

  final SearchItem item;

  @override
  Widget build(BuildContext context) {
    final subtitle = '${item.specialty} • ${item.locationLabel}'.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.person_outline,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.isAvailableSoon)
                    const _TagChip(label: 'Disponible bientôt'),
                  const _TagChip(label: 'Paiement sur place'),
                  if (item.isVerified) const _TagChip(label: 'Vérifié'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.data});

  final ResolvedPractitionerData data;

  @override
  Widget build(BuildContext context) {
    final hasBio = data.bio.trim().isNotEmpty;
    final hasLanguages = data.languages.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasBio) ...[
              Text(
                data.bio,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              Text(
                'Présentation du praticien bientôt disponible.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
            if (hasLanguages) ...[
              const SizedBox(height: 14),
              Text(
                'Langues parlées',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.languages
                    .map((language) => _TagChip(label: language))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.selected,
    required this.onSelect,
  });

  final DateTime selected;
  final void Function(DateTime day) onSelect;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now();
    final days = List<DateTime>.generate(7, (index) {
      return DateTime(start.year, start.month, start.day)
          .add(Duration(days: index));
    });

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == selected.year &&
              day.month == selected.month &&
              day.day == selected.day;

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(day),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dowShort(day),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          height: 1.0,
                          color:
                              isSelected ? Colors.white : AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : null,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dowShort(DateTime date) {
    const map = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mer',
      4: 'Jeu',
      5: 'Ven',
      6: 'Sam',
      7: 'Dim',
    };
    return map[date.weekday] ?? '';
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.label,
    required this.summary,
  });

  final String label;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingAvailabilityCard extends StatelessWidget {
  const _LoadingAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text('Chargement des créneaux disponibles...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityMessageCard extends StatelessWidget {
  const _AvailabilityMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotsGrid extends StatelessWidget {
  const _SlotsGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  final List<String> slots;
  final String? selectedSlot;
  final void Function(String slot) onSelect;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Aucun créneau disponible.'),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = slot == selectedSlot;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelect(slot),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              slot,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : null,
                  ),
            ),
          ),
        );
      },
    );
  }
}