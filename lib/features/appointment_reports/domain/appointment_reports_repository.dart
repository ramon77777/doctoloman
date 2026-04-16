import 'appointment_report.dart';

abstract class AppointmentReportsRepository {
  Future<List<AppointmentReport>> listAll();

  Future<AppointmentReport?> getById(String id);

  Future<AppointmentReport?> getByAppointmentId(String appointmentId);

  Future<void> save(AppointmentReport report);

  Future<void> deleteById(String id);

  Future<void> clear();
}