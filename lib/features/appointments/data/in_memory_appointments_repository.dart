import 'appointments_local_storage.dart';
import '../domain/appointment.dart';
import '../domain/appointments_repository.dart';

class InMemoryAppointmentsRepository implements AppointmentsRepository {
  InMemoryAppointmentsRepository(this._localStorage);

  final AppointmentsLocalStorage _localStorage;

  List<Appointment>? _cache;

  Future<List<Appointment>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<Appointment> items) async {
    _cache = List<Appointment>.from(items);
    await _localStorage.saveAll(_cache!);
  }

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final da = _normalizeDay(a);
    final db = _normalizeDay(b);
    return da == db;
  }

  bool _isSlotAlreadyTaken(
    List<Appointment> items,
    Appointment candidate, {
    String? excludeAppointmentId,
  }) {
    for (final item in items) {
      if (excludeAppointmentId != null && item.id == excludeAppointmentId) {
        continue;
      }

      final samePractitioner = item.practitionerId == candidate.practitionerId;
      final sameDay = _isSameDay(item.day, candidate.day);
      final sameSlot = item.slot == candidate.slot;
      final stillActive = !item.isCancelledLike;

      if (samePractitioner && sameDay && sameSlot && stillActive) {
        return true;
      }
    }
    return false;
  }

  @override
    Future<void> create(Appointment appointment) async {
      final items = await _loadItems();

      if (_isSlotAlreadyTaken(items, appointment)) {
        throw AppointmentSlotUnavailableException(
          practitionerId: appointment.practitionerId,
          day: appointment.day,
          slot: appointment.slot,
        );
      }

      final updated = List<Appointment>.from(items)..add(appointment);
      await _persist(updated);
    }

  @override
    Future<AppointmentListResult> list(AppointmentListQuery query) async {
      final items = await _loadItems();
      var filtered = List<Appointment>.from(items);

      final practitionerId = query.practitionerId?.trim();
      if (practitionerId != null && practitionerId.isNotEmpty) {
        filtered = filtered
            .where((item) => item.practitionerId.trim() == practitionerId)
            .toList();
      }

      if (query.status != null) {
        filtered = filtered.where((item) => item.status == query.status).toList();
      }

      if (query.from != null) {
        filtered = filtered
            .where((item) => !item.scheduledAt.isBefore(query.from!))
            .toList();
      }

      if (query.to != null) {
        filtered = filtered
            .where((item) => !item.scheduledAt.isAfter(query.to!))
            .toList();
      }

      filtered.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

      final safePage = query.page < 1 ? 1 : query.page;
      final safePageSize = query.pageSize < 1 ? 50 : query.pageSize;

      final start = (safePage - 1) * safePageSize;
      final end = start + safePageSize;

      final paged = start >= filtered.length
          ? <Appointment>[]
          : filtered.sublist(
              start,
              end > filtered.length ? filtered.length : end,
            );

      return AppointmentListResult(
        items: List<Appointment>.unmodifiable(paged),
        totalCount: filtered.length,
        page: safePage,
        pageSize: safePageSize,
      );
    }

  @override
  Future<Appointment?> getById(String id) async {
    final normalizedId = id.trim();
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
  Future<void> updateStatus({
    required String id,
    required AppointmentStatus status,
  }) async {
    final items = await _loadItems();
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final updated = List<Appointment>.from(items);
    updated[index] = updated[index].copyWith(status: status);
    await _persist(updated);
  }

  @override
  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  }) async {
    final items = await _loadItems();
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return null;

    final current = items[index];
    if (current.isCancelledLike) {
      return null;
    }

    final normalizedDay = _normalizeDay(day);
    final normalizedSlot = slot.trim();

    final candidate = current.copyWith(
      day: normalizedDay,
      slot: normalizedSlot,
    );

    if (_isSlotAlreadyTaken(
      items,
      candidate,
      excludeAppointmentId: current.id,
    )) {
      throw AppointmentSlotUnavailableException(
        practitionerId: candidate.practitionerId,
        day: candidate.day,
        slot: candidate.slot,
      );
    }

    final updated = List<Appointment>.from(items);
    updated[index] = candidate;
    await _persist(updated);

    return candidate;
  }

  @override
  Future<void> clear() async {
    _cache = <Appointment>[];
    await _localStorage.clear();
  }
}