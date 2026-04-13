import '../../domain/professional_schedule.dart';
import '../professional_schedule_local_storage.dart';

class ProfessionalScheduleLocalDataSource {
  ProfessionalScheduleLocalDataSource(this._storage);

  final ProfessionalScheduleLocalStorage _storage;

  Future<Map<String, List<DaySchedule>>> readAll() {
    return _storage.readAll();
  }

  Future<void> writeAll(Map<String, List<DaySchedule>> data) {
    return _storage.writeAll(data);
  }

  Future<void> clear() {
    return _storage.clear();
  }
}