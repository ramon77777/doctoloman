import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_notifications_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/appointments_local_storage.dart';
import '../../data/in_memory_appointments_repository.dart';
import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';

final appointmentsLocalStorageProvider = Provider<AppointmentsLocalStorage>(
  (ref) => AppointmentsLocalStorage(ref.watch(sharedPreferencesProvider)),
  name: 'appointmentsLocalStorageProvider',
);

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => InMemoryAppointmentsRepository(
    ref.watch(appointmentsLocalStorageProvider),
  ),
  name: 'appointmentsRepositoryProvider',
);

/// Liste brute de tous les rendez-vous présents dans le stockage local.
/// Cette source sert notamment au calcul des créneaux déjà pris.
final allAppointmentsProvider = FutureProvider<List<Appointment>>(
  (ref) async {
    final repo = ref.watch(appointmentsRepositoryProvider);
    final result = await repo.list(
      AppointmentListQuery(
        page: 1,
        pageSize: 500,
      ),
    );

    return List<Appointment>.unmodifiable(result.items);
  },
  name: 'allAppointmentsProvider',
);

/// Liste des rendez-vous visibles pour le patient connecté.
/// On filtre par téléphone patient pour éviter de mélanger les rendez-vous
/// de plusieurs sessions/utilisateurs sur un même stockage local mock.
final appointmentsListProvider = FutureProvider<List<Appointment>>(
  (ref) async {
    final authState = ref.watch(authControllerProvider);
    final authUser = authState.user;
    final allItems = await ref.watch(allAppointmentsProvider.future);

    if (authUser == null) {
      return const <Appointment>[];
    }

    final normalizedPhone = _normalizePhoneKey(authUser.phone);
    if (normalizedPhone.isEmpty) {
      return const <Appointment>[];
    }

    final filtered = allItems.where((appointment) {
      return _normalizePhoneKey(appointment.patientPhoneE164) == normalizedPhone;
    }).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return List<Appointment>.unmodifiable(filtered);
  },
  name: 'appointmentsListProvider',
);

final appointmentByIdProvider =
    FutureProvider.family<Appointment?, String>((ref, id) async {
  final normalizedId = _normalizeKey(id);
  if (normalizedId.isEmpty) return null;

  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;
  if (authUser == null) return null;

  final repo = ref.watch(appointmentsRepositoryProvider);
  final appointment = await repo.getById(normalizedId);
  if (appointment == null) return null;

  final normalizedPhone = _normalizePhoneKey(authUser.phone);
  if (_normalizePhoneKey(appointment.patientPhoneE164) != normalizedPhone) {
    return null;
  }

  return appointment;
}, name: 'appointmentByIdProvider');

final appointmentsControllerProvider = Provider<AppointmentsController>(
  (ref) {
    final repo = ref.watch(appointmentsRepositoryProvider);
    return AppointmentsController(
      ref: ref,
      repo: repo,
      notifications: LocalNotificationsService.instance,
    );
  },
  name: 'appointmentsControllerProvider',
);

enum AppointmentsViewFilter {
  all,
  pending,
  upcoming,
  history,
  cancelled,
}

@immutable
class AppointmentsFilters {
  const AppointmentsFilters({
    required this.query,
    required this.filter,
  });

  final String query;
  final AppointmentsViewFilter filter;

  AppointmentsFilters copyWith({
    String? query,
    AppointmentsViewFilter? filter,
  }) {
    return AppointmentsFilters(
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }

  static const initial = AppointmentsFilters(
    query: '',
    filter: AppointmentsViewFilter.all,
  );
}

class AppointmentsFiltersController
    extends StateNotifier<AppointmentsFilters> {
  AppointmentsFiltersController() : super(AppointmentsFilters.initial);

  void setQuery(String value) {
    final normalized = _normalizeSearch(value);
    if (normalized == state.query) return;
    state = state.copyWith(query: normalized);
  }

  void clearQuery() {
    if (state.query.isEmpty) return;
    state = state.copyWith(query: '');
  }

  void setFilter(AppointmentsViewFilter value) {
    if (value == state.filter) return;
    state = state.copyWith(filter: value);
  }

  void reset() {
    if (state == AppointmentsFilters.initial) return;
    state = AppointmentsFilters.initial;
  }
}

final appointmentsFiltersProvider =
    StateNotifierProvider<AppointmentsFiltersController, AppointmentsFilters>(
  (ref) => AppointmentsFiltersController(),
  name: 'appointmentsFiltersProvider',
);

@immutable
class AppointmentsStats {
  const AppointmentsStats({
    required this.totalCount,
    required this.pendingCount,
    required this.upcomingConfirmedCount,
    required this.confirmedCount,
    required this.historyCount,
    required this.cancelledCount,
  });

  final int totalCount;
  final int pendingCount;
  final int upcomingConfirmedCount;
  final int confirmedCount;
  final int historyCount;
  final int cancelledCount;
}

final appointmentsStatsProvider = FutureProvider<AppointmentsStats>(
  (ref) async {
    final items = await ref.watch(appointmentsListProvider.future);

    return AppointmentsStats(
      totalCount: items.length,
      pendingCount: items.where(_isPendingAppointment).length,
      upcomingConfirmedCount:
          items.where(_isUpcomingConfirmedAppointment).length,
      confirmedCount: items.where(_isConfirmedAppointment).length,
      historyCount: items.where(_isHistoryAppointment).length,
      cancelledCount: items.where(_isCancelledAppointment).length,
    );
  },
  name: 'appointmentsStatsProvider',
);

final nextUpcomingAppointmentProvider = FutureProvider<Appointment?>(
  (ref) async {
    final items = await ref.watch(appointmentsListProvider.future);

    final upcoming = items.where(_isUpcomingConfirmedAppointment).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return upcoming.isEmpty ? null : upcoming.first;
  },
  name: 'nextUpcomingAppointmentProvider',
);

final filteredAppointmentsProvider = FutureProvider<List<Appointment>>(
  (ref) async {
    final items = await ref.watch(appointmentsListProvider.future);
    final filters = ref.watch(appointmentsFiltersProvider);

    final searchedItems = items.where(
      (appointment) => _matchesAppointmentSearch(
        appointment: appointment,
        query: filters.query,
      ),
    );

    final filtered = searchedItems.where(
      (appointment) => _matchesViewFilter(
        appointment: appointment,
        filter: filters.filter,
      ),
    ).toList();

    filtered.sort(
      (a, b) => _compareAppointmentsForViewFilter(
        a: a,
        b: b,
        filter: filters.filter,
      ),
    );

    return List<Appointment>.unmodifiable(filtered);
  },
  name: 'filteredAppointmentsProvider',
);

@immutable
class TakenSlotsQuery {
  const TakenSlotsQuery({
    required this.practitionerId,
    required this.day,
  });

  final String practitionerId;
  final DateTime day;

  DateTime get normalizedDay => DateTime(day.year, day.month, day.day);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TakenSlotsQuery &&
        _normalizeKey(other.practitionerId) == _normalizeKey(practitionerId) &&
        other.normalizedDay == normalizedDay;
  }

  @override
  int get hashCode => Object.hash(
        _normalizeKey(practitionerId),
        normalizedDay,
      );
}

/// Calcule les créneaux déjà pris pour un praticien donné et une journée donnée.
/// Ici on se base sur la source brute de rendez-vous, pas sur la liste filtrée
/// du patient connecté, sinon la disponibilité deviendrait incohérente.
final takenSlotsForPractitionerDayProvider =
    FutureProvider.family<Set<String>, TakenSlotsQuery>((ref, query) async {
  final items = await ref.watch(allAppointmentsProvider.future);
  final normalizedPractitionerId = _normalizeKey(query.practitionerId);
  final targetDay = query.normalizedDay;

  final takenSlots = items.where((appointment) {
    if (_normalizeKey(appointment.practitionerId) != normalizedPractitionerId) {
      return false;
    }

    if (!_isSlotBlockingAppointment(appointment)) {
      return false;
    }

    return _isSameCalendarDay(appointment.day, targetDay);
  }).map((appointment) {
    return _normalizeSlot(appointment.slot);
  }).where((slot) {
    return slot.isNotEmpty;
  }).toSet();

  return Set<String>.unmodifiable(takenSlots);
}, name: 'takenSlotsForPractitionerDayProvider');

class AppointmentsController {
  AppointmentsController({
    required Ref ref,
    required AppointmentsRepository repo,
    required LocalNotificationsService notifications,
  })  : _ref = ref,
        _repo = repo,
        _notifications = notifications;

  final Ref _ref;
  final AppointmentsRepository _repo;
  final LocalNotificationsService _notifications;

  Future<void> create(Appointment appointment) async {
    await _repo.create(appointment);
    await _notifications.syncAppointment(appointment);

    _invalidateCollections();
    _invalidateAppointment(appointment.id);
    _invalidateTakenSlots(
      practitionerId: appointment.practitionerId,
      day: appointment.day,
    );
  }

  Future<void> updateStatus({
    required String id,
    required AppointmentStatus status,
  }) async {
    final before = await _repo.getById(id);

    await _repo.updateStatus(id: id, status: status);

    final updated = await _repo.getById(id);
    await _syncNotificationForAppointment(id: id, appointment: updated);

    _invalidateCollections();
    _invalidateAppointment(id);

    if (before != null) {
      _invalidateTakenSlots(
        practitionerId: before.practitionerId,
        day: before.day,
      );
    }

    if (updated != null) {
      _invalidateTakenSlots(
        practitionerId: updated.practitionerId,
        day: updated.day,
      );
    }
  }

  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  }) async {
    final before = await _repo.getById(id);
    if (before == null) return null;

    final updated = await _repo.reschedule(
      id: id,
      day: day,
      slot: slot,
    );

    await _syncNotificationForAppointment(id: id, appointment: updated);

    _invalidateCollections();
    _invalidateAppointment(id);

    _invalidateTakenSlots(
      practitionerId: before.practitionerId,
      day: before.day,
    );

    if (updated != null) {
      _invalidateTakenSlots(
        practitionerId: updated.practitionerId,
        day: updated.day,
      );
    }

    return updated;
  }

  Future<void> clear() async {
    final result = await _repo.list(
      AppointmentListQuery(
        page: 1,
        pageSize: 500,
      ),
    );
    final items = result.items;

    await _repo.clear();

    for (final item in items) {
      await _notifications.cancelAppointmentReminder(item.id);
    }

    _invalidateCollections();

    for (final item in items) {
      _invalidateAppointment(item.id);
      _invalidateTakenSlots(
        practitionerId: item.practitionerId,
        day: item.day,
      );
    }
  }

  Future<void> _syncNotificationForAppointment({
    required String id,
    required Appointment? appointment,
  }) async {
    if (appointment != null) {
      await _notifications.syncAppointment(appointment);
      return;
    }

    await _notifications.cancelAppointmentReminder(id);
  }

  void _invalidateCollections() {
    _ref.invalidate(allAppointmentsProvider);
    _ref.invalidate(appointmentsListProvider);
    _ref.invalidate(appointmentsStatsProvider);
    _ref.invalidate(nextUpcomingAppointmentProvider);
    _ref.invalidate(filteredAppointmentsProvider);
  }

  void _invalidateAppointment(String id) {
    _ref.invalidate(appointmentByIdProvider(id));
  }

  void _invalidateTakenSlots({
    required String practitionerId,
    required DateTime day,
  }) {
    _ref.invalidate(
      takenSlotsForPractitionerDayProvider(
        TakenSlotsQuery(
          practitionerId: practitionerId,
          day: day,
        ),
      ),
    );
  }
}

bool _matchesAppointmentSearch({
  required Appointment appointment,
  required String query,
}) {
  if (query.isEmpty) return true;

  final haystack = _normalizeSearch(
    '${appointment.practitionerName} '
    '${appointment.specialty} '
    '${appointment.reason} '
    '${appointment.fullAddress} '
    '${appointment.slot}',
  );

  return haystack.contains(query);
}

bool _matchesViewFilter({
  required Appointment appointment,
  required AppointmentsViewFilter filter,
}) {
  switch (filter) {
    case AppointmentsViewFilter.all:
      return true;
    case AppointmentsViewFilter.pending:
      return _isPendingAppointment(appointment);
    case AppointmentsViewFilter.upcoming:
      return _isUpcomingConfirmedAppointment(appointment);
    case AppointmentsViewFilter.history:
      return _isHistoryAppointment(appointment);
    case AppointmentsViewFilter.cancelled:
      return _isCancelledAppointment(appointment);
  }
}

int _compareAppointmentsForViewFilter({
  required Appointment a,
  required Appointment b,
  required AppointmentsViewFilter filter,
}) {
  switch (filter) {
    case AppointmentsViewFilter.pending:
    case AppointmentsViewFilter.upcoming:
      return a.scheduledAt.compareTo(b.scheduledAt);
    case AppointmentsViewFilter.history:
    case AppointmentsViewFilter.cancelled:
    case AppointmentsViewFilter.all:
      return b.scheduledAt.compareTo(a.scheduledAt);
  }
}

bool _isPendingAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.pending;
}

bool _isConfirmedAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.confirmed;
}

bool _isUpcomingConfirmedAppointment(Appointment appointment) {
  return _isConfirmedAppointment(appointment) && appointment.isUpcoming;
}

bool _isHistoryAppointment(Appointment appointment) {
  return _isConfirmedAppointment(appointment) && !appointment.isUpcoming;
}

bool _isCancelledAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.cancelledByPatient ||
      appointment.status == AppointmentStatus.declinedByProfessional;
}

bool _isSlotBlockingAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.pending ||
      appointment.status == AppointmentStatus.confirmed;
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _normalizeSlot(String value) {
  return value.trim();
}

String _normalizeKey(String value) {
  return value.trim();
}

String _normalizePhoneKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.replaceAll(RegExp(r'\D'), '');
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}