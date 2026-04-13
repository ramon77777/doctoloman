import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';

/// Datasource distante préparée pour le futur backend.
///
/// Pour l’instant, elle sert d’interface technique propre.
/// Quand l’API sera prête, on branchera ici les appels HTTP.
abstract class AppointmentsRemoteDataSource {
  Future<AppointmentListResult> list(AppointmentListQuery query);

  Future<Appointment?> getById(String id);

  Future<Appointment> create(Appointment appointment);

  Future<Appointment?> updateStatus({
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

/// Implémentation mock "backend-ready".
///
/// Aujourd’hui elle ne parle pas à un vrai serveur.
/// Demain, elle pourra être remplacée par une implémentation HTTP
/// sans toucher l’UI ni le domaine.
class FakeAppointmentsRemoteDataSource implements AppointmentsRemoteDataSource {
  const FakeAppointmentsRemoteDataSource();

  @override
  Future<void> clear() async {}

  @override
  Future<Appointment> create(Appointment appointment) async {
    return appointment;
  }

  @override
  Future<Appointment?> getById(String id) async {
    return null;
  }

  @override
  Future<AppointmentListResult> list(AppointmentListQuery query) async {
    return AppointmentListResult(
      items: const [],
      totalCount: 0,
      page: query.safePage,
      pageSize: query.safePageSize,
    );
  }

  @override
  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  }) async {
    return null;
  }

  @override
  Future<Appointment?> updateStatus({
    required String id,
    required AppointmentStatus status,
  }) async {
    return null;
  }
}