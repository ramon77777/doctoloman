import 'appointment_reports_local_storage.dart';
import '../domain/appointment_report.dart';
import '../domain/appointment_reports_repository.dart';

class InMemoryAppointmentReportsRepository
    implements AppointmentReportsRepository {
  InMemoryAppointmentReportsRepository(this._localStorage);

  final AppointmentReportsLocalStorage _localStorage;

  List<AppointmentReport>? _cache;

  Future<List<AppointmentReport>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<AppointmentReport> items) async {
    _cache = List<AppointmentReport>.unmodifiable(items);
    await _localStorage.saveAll(_cache!);
  }

  String _normalize(String value) => value.trim();

  @override
  Future<List<AppointmentReport>> listAll() async {
    final items = await _loadItems();
    final sorted = [...items]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<AppointmentReport>.unmodifiable(sorted);
  }

  @override
  Future<AppointmentReport?> getById(String id) async {
    final normalizedId = _normalize(id);
    if (normalizedId.isEmpty) return null;

    final items = await _loadItems();
    for (final item in items) {
      if (item.id == normalizedId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<AppointmentReport?> getByAppointmentId(String appointmentId) async {
    final normalizedAppointmentId = _normalize(appointmentId);
    if (normalizedAppointmentId.isEmpty) return null;

    final items = await _loadItems();
    for (final item in items) {
      if (item.appointmentId == normalizedAppointmentId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> save(AppointmentReport report) async {
    final normalizedReportId = _normalize(report.id);
    final normalizedAppointmentId = _normalize(report.appointmentId);

    if (normalizedReportId.isEmpty || normalizedAppointmentId.isEmpty) {
      return;
    }

    final items = await _loadItems();
    final updated = List<AppointmentReport>.from(items);

    final index = updated.indexWhere((e) => e.id == normalizedReportId);
    if (index >= 0) {
      updated[index] = report;
    } else {
      final existingByAppointmentIndex = updated.indexWhere(
        (e) => e.appointmentId == normalizedAppointmentId,
      );

      if (existingByAppointmentIndex >= 0) {
        updated[existingByAppointmentIndex] = report;
      } else {
        updated.add(report);
      }
    }

    await _persist(updated);
  }

  @override
  Future<void> deleteById(String id) async {
    final normalizedId = _normalize(id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final updated = items.where((e) => e.id != normalizedId).toList();
    await _persist(updated);
  }

  @override
  Future<void> clear() async {
    _cache = <AppointmentReport>[];
    await _localStorage.clear();
  }
}