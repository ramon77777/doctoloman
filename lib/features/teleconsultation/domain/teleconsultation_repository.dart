import 'teleconsultation_session.dart';

abstract class TeleconsultationRepository {
  Future<List<TeleconsultationSession>> listAll();

  Future<TeleconsultationSession?> getById(String id);

  Future<TeleconsultationSession?> getByAppointmentId(String appointmentId);

  Future<void> upsert(TeleconsultationSession session);

  Future<void> deleteById(String id);

  Future<void> clear();
}