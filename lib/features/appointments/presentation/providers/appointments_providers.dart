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

final appointmentsListProvider = FutureProvider<List<Appointment>>(
  (ref) async {
    final repo = ref.watch(appointmentsRepositoryProvider);
    final result = await repo.list(
      const AppointmentListQuery(
        page: 1,
        pageSize: 500,
      ),
    );
    return result.items;
  },
  name: 'appointmentsListProvider',
);

final appointmentByIdProvider =
    FutureProvider.family<Appointment?, String>((ref, id) async {
  final repo = ref.watch(appointmentsRepositoryProvider);
  return repo.getById(id);
}, name: 'appointmentByIdProvider');

final appointmentsControllerProvider = Provider<AppointmentsController>(
  (ref) {
    final repo = ref.watch(appointmentsRepositoryProvider);
    return AppointmentsController(ref: ref, repo: repo);
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
    state = state.copyWith(query: value);
  }

  void clearQuery() {
    state = state.copyWith(query: '');
  }

  void setFilter(AppointmentsViewFilter value) {
    state = state.copyWith(filter: value);
  }

  void reset() {
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

    final pendingCount = items
        .where((a) => a.status == AppointmentStatus.pending)
        .length;

    final upcomingConfirmedCount = items
        .where(
          (a) => a.status == AppointmentStatus.confirmed && a.isUpcoming,
        )
        .length;

    final confirmedCount = items
        .where((a) => a.status == AppointmentStatus.confirmed)
        .length;

    final historyCount = items
        .where(
          (a) => a.status == AppointmentStatus.confirmed && !a.isUpcoming,
        )
        .length;

    final cancelledCount = items
        .where(
          (a) =>
              a.status == AppointmentStatus.cancelledByPatient ||
              a.status == AppointmentStatus.declinedByProfessional,
        )
        .length;

    return AppointmentsStats(
      totalCount: items.length,
      pendingCount: pendingCount,
      upcomingConfirmedCount: upcomingConfirmedCount,
      confirmedCount: confirmedCount,
      historyCount: historyCount,
      cancelledCount: cancelledCount,
    );
  },
  name: 'appointmentsStatsProvider',
);

final nextUpcomingAppointmentProvider = FutureProvider<Appointment?>(
  (ref) async {
    final items = await ref.watch(appointmentsListProvider.future);

    final upcoming = items
        .where(
          (a) => a.status == AppointmentStatus.confirmed && a.isUpcoming,
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (upcoming.isEmpty) return null;
    return upcoming.first;
  },
  name: 'nextUpcomingAppointmentProvider',
);

final filteredAppointmentsProvider = FutureProvider<List<Appointment>>(
  (ref) async {
    final items = await ref.watch(appointmentsListProvider.future);
    final filters = ref.watch(appointmentsFiltersProvider);

    final query = _normalize(filters.query);

    final searchedItems = items.where((appointment) {
      if (query.isEmpty) return true;

      final haystack = _normalize(
        '${appointment.practitionerName} '
        '${appointment.specialty} '
        '${appointment.reason} '
        '${appointment.fullAddress} '
        '${appointment.slot}',
      );

      return haystack.contains(query);
    }).toList();

    final filtered = switch (filters.filter) {
      AppointmentsViewFilter.all => searchedItems,
      AppointmentsViewFilter.pending => searchedItems
          .where((a) => a.status == AppointmentStatus.pending)
          .toList(),
      AppointmentsViewFilter.upcoming => searchedItems
          .where(
            (a) => a.status == AppointmentStatus.confirmed && a.isUpcoming,
          )
          .toList(),
      AppointmentsViewFilter.history => searchedItems
          .where(
            (a) => a.status == AppointmentStatus.confirmed && !a.isUpcoming,
          )
          .toList(),
      AppointmentsViewFilter.cancelled => searchedItems
          .where(
            (a) =>
                a.status == AppointmentStatus.cancelledByPatient ||
                a.status == AppointmentStatus.declinedByProfessional,
          )
          .toList(),
    };

    filtered.sort((a, b) {
      switch (filters.filter) {
        case AppointmentsViewFilter.pending:
        case AppointmentsViewFilter.upcoming:
          return a.scheduledAt.compareTo(b.scheduledAt);
        case AppointmentsViewFilter.history:
        case AppointmentsViewFilter.cancelled:
          return b.scheduledAt.compareTo(a.scheduledAt);
        case AppointmentsViewFilter.all:
          return b.scheduledAt.compareTo(a.scheduledAt);
      }
    });

    return filtered;
  },
  name: 'filteredAppointmentsProvider',
);

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
        other.practitionerId == practitionerId &&
        other.normalizedDay == normalizedDay;
  }

  @override
  int get hashCode => Object.hash(practitionerId, normalizedDay);
}

final takenSlotsForPractitionerDayProvider =
    FutureProvider.family<Set<String>, TakenSlotsQuery>((ref, query) async {
  final items = await ref.watch(appointmentsListProvider.future);

  final targetDay = DateTime(
    query.day.year,
    query.day.month,
    query.day.day,
  );

  final taken = items.where((appointment) {
    if (appointment.practitionerId != query.practitionerId) return false;
    if (appointment.isCancelledLike) return false;

    final appointmentDay = DateTime(
      appointment.day.year,
      appointment.day.month,
      appointment.day.day,
    );

    return appointmentDay == targetDay;
  }).map((appointment) => appointment.slot).toSet();

  return taken;
}, name: 'takenSlotsForPractitionerDayProvider');

class AppointmentsController {
  AppointmentsController({
    required Ref ref,
    required AppointmentsRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final AppointmentsRepository _repo;

  Future<void> create(Appointment appointment) async {
    await _repo.create(appointment);
    await LocalNotificationsService.instance.syncAppointment(appointment);

    _invalidateCollections();
    _ref.invalidate(appointmentByIdProvider(appointment.id));
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
    if (updated != null) {
      await LocalNotificationsService.instance.syncAppointment(updated);
    } else {
      await LocalNotificationsService.instance.cancelAppointmentReminder(id);
    }

    _invalidateCollections();
    _ref.invalidate(appointmentByIdProvider(id));

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

    if (updated != null) {
      await LocalNotificationsService.instance.syncAppointment(updated);
    }

    _invalidateCollections();
    _ref.invalidate(appointmentByIdProvider(id));

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
      const AppointmentListQuery(
        page: 1,
        pageSize: 500,
      ),
    );
    final items = result.items;

    await _repo.clear();

    for (final item in items) {
      await LocalNotificationsService.instance
          .cancelAppointmentReminder(item.id);
    }

    _invalidateCollections();
    for (final item in items) {
      _ref.invalidate(appointmentByIdProvider(item.id));
      _invalidateTakenSlots(
        practitionerId: item.practitionerId,
        day: item.day,
      );
    }
  }

  void _invalidateCollections() {
    _ref.invalidate(appointmentsListProvider);
    _ref.invalidate(appointmentsStatsProvider);
    _ref.invalidate(nextUpcomingAppointmentProvider);
    _ref.invalidate(filteredAppointmentsProvider);
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

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}