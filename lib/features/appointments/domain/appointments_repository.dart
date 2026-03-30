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

  @override
  String toString() {
    return 'AppointmentSlotUnavailableException('
        'practitionerId: $practitionerId, '
        'day: $day, '
        'slot: $slot'
        ')';
  }
}

class AppointmentListQuery {
  const AppointmentListQuery({
    this.practitionerId,
    this.status,
    this.from,
    this.to,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? practitionerId;
  final AppointmentStatus? status;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int pageSize;
}

class AppointmentListResult {
  const AppointmentListResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<Appointment> items;
  final int totalCount;
  final int page;
  final int pageSize;
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