import '../../domain/professional_schedule.dart';

abstract class ProfessionalScheduleRemoteDataSource {
  Future<Map<String, List<DaySchedule>>> fetchAll({
    String? currentProfessionalId,
  });

  Future<List<DaySchedule>?> fetchSchedule(String practitionerId);

  Future<void> saveSchedule({
    required String practitionerId,
    required List<DaySchedule> schedule,
  });

  Future<void> resetDefaults(String practitionerId);
}

class FakeProfessionalScheduleRemoteDataSource
    implements ProfessionalScheduleRemoteDataSource {
  const FakeProfessionalScheduleRemoteDataSource();

  @override
  Future<Map<String, List<DaySchedule>>> fetchAll({
    String? currentProfessionalId,
  }) async {
    return <String, List<DaySchedule>>{};
  }

  @override
  Future<List<DaySchedule>?> fetchSchedule(String practitionerId) async {
    return null;
  }

  @override
  Future<void> saveSchedule({
    required String practitionerId,
    required List<DaySchedule> schedule,
  }) async {}

  @override
  Future<void> resetDefaults(String practitionerId) async {}
}