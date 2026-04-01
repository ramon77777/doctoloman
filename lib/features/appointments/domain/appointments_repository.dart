import 'appointment.dart';

class AppointmentSlotUnavailableException implements Exception {
  const AppointmentSlotUnavailableException({
    required this.practitionerId,
    required this.day,
    required this.slot,
  });

  final String practitionerId;
  final DateTime day;
  final String slot;

  DateTime get normalizedDay => DateTime(day.year, day.month, day.day);

  @override
  String toString() {
    return 'AppointmentSlotUnavailableException('
        'practitionerId: $practitionerId, '
        'day: $normalizedDay, '
        'slot: $slot'
        ')';
  }
}

class AppointmentListQuery {
  AppointmentListQuery({
    String? practitionerId,
    this.status,
    DateTime? from,
    DateTime? to,
    this.page = 1,
    this.pageSize = 50,
  })  : practitionerId = _normalizeOptionalText(practitionerId),
        from = from,
        to = to;

  final String? practitionerId;
  final AppointmentStatus? status;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int pageSize;

  int get safePage => page < 1 ? 1 : page;
  int get safePageSize => pageSize < 1 ? 50 : pageSize;

  AppointmentListQuery copyWith({
    String? practitionerId,
    bool clearPractitionerId = false,
    AppointmentStatus? status,
    bool clearStatus = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    int? page,
    int? pageSize,
  }) {
    return AppointmentListQuery(
      practitionerId: clearPractitionerId
          ? null
          : (practitionerId ?? this.practitionerId),
      status: clearStatus ? null : (status ?? this.status),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppointmentListQuery &&
        other.practitionerId == practitionerId &&
        other.status == status &&
        other.from == from &&
        other.to == to &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      practitionerId,
      status,
      from,
      to,
      page,
      pageSize,
    );
  }

  @override
  String toString() {
    return 'AppointmentListQuery('
        'practitionerId: $practitionerId, '
        'status: $status, '
        'from: $from, '
        'to: $to, '
        'page: $page, '
        'pageSize: $pageSize'
        ')';
  }
}

class AppointmentListResult {
  AppointmentListResult({
    required List<Appointment> items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  }) : items = List<Appointment>.unmodifiable(items);

  final List<Appointment> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  @override
  String toString() {
    return 'AppointmentListResult('
        'items: ${items.length}, '
        'totalCount: $totalCount, '
        'page: $page, '
        'pageSize: $pageSize'
        ')';
  }
}

abstract class AppointmentsRepository {
  Future<void> create(Appointment appointment);

  Future<AppointmentListResult> list(AppointmentListQuery query);

  Future<Appointment?> getById(String id);

  Future<void> updateStatus({
    required String id,
    required AppointmentStatus status,
  });

  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  });

  Future<void> clear();
}

String? _normalizeOptionalText(String? value) {
  if (value == null) return null;

  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}