import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';
import '../appointments_local_storage.dart';

class AppointmentsLocalDataSource {
  AppointmentsLocalDataSource(this._storage);

  final AppointmentsLocalStorage _storage;

  Future<List<Appointment>> readAll() {
    return _storage.readAll();
  }

  Future<void> writeAll(List<Appointment> appointments) {
    return _storage.saveAll(appointments);
  }

  Future<void> clear() {
    return _storage.clear();
  }

  Future<Appointment?> getById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;

    final items = await readAll();
    for (final item in items) {
      if (item.id.trim() == normalizedId) {
        return item;
      }
    }
    return null;
  }

  Future<AppointmentListResult> list(AppointmentListQuery query) async {
    final items = await readAll();
    var filtered = List<Appointment>.from(items);

    final practitionerId = query.practitionerId?.trim();
    if (practitionerId != null && practitionerId.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.practitionerId.trim() == practitionerId;
      }).toList();
    }

    if (query.status != null) {
      filtered = filtered.where((item) => item.status == query.status).toList();
    }

    if (query.from != null) {
      filtered =
          filtered.where((item) => !item.scheduledAt.isBefore(query.from!)).toList();
    }

    if (query.to != null) {
      filtered =
          filtered.where((item) => !item.scheduledAt.isAfter(query.to!)).toList();
    }

    filtered.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    final start = (query.safePage - 1) * query.safePageSize;
    final end = start + query.safePageSize;

    final paged = start >= filtered.length
        ? <Appointment>[]
        : filtered.sublist(
            start,
            end > filtered.length ? filtered.length : end,
          );

    return AppointmentListResult(
      items: paged,
      totalCount: filtered.length,
      page: query.safePage,
      pageSize: query.safePageSize,
    );
  }

  Future<void> replaceAll(List<Appointment> appointments) async {
    await writeAll(appointments);
  }
}