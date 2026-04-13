import 'professional_schedule.dart';

abstract class ProfessionalScheduleRepository {
  Future<Map<String, List<DaySchedule>>> readAll({
    String? currentProfessionalId,
  });

  Future<List<DaySchedule>> scheduleFor(
    String practitionerId, {
    String? currentProfessionalId,
  });

  Future<Map<String, List<DaySchedule>>> replaceSchedule({
    required String practitionerId,
    required List<DaySchedule> schedule,
    String? currentProfessionalId,
  });

  Future<Map<String, List<DaySchedule>>> resetDefaults({
    required String practitionerId,
    String? currentProfessionalId,
  });
}