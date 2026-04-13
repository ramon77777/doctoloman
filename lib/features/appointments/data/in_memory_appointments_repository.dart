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
    _cache = List<Appointment>.unmodifiable(items);
    await _localStorage.saveAll(_cache!);
  }

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _normalizeId(String value) {
    return value.trim();
  }

  String _normalizePractitionerId(String value) {
    return value.trim();
  }

  String _normalizeSlot(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parts = trimmed.split(':');
    if (parts.length != 2) {
      return trimmed;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return trimmed;
    }

    final hh = hour.clamp(0, 23).toString().padLeft(2, '0');
    final mm = minute.clamp(0, 59).toString().padLeft(2, '0');

    return '$hh:$mm';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return _normalizeDay(a) == _normalizeDay(b);
  }

  Appointment _normalizeAppointment(Appointment appointment) {
    return appointment.copyWith(
      id: _normalizeId(appointment.id),
      practitionerId: _normalizePractitionerId(appointment.practitionerId),
      day: _normalizeDay(appointment.day),
      slot: _normalizeSlot(appointment.slot),
      patientPhoneE164: appointment.patientPhoneE164.trim(),
      practitionerName: appointment.practitionerName.trim(),
      specialty: appointment.specialty.trim(),
      address: appointment.address.trim(),
      city: appointment.city.trim(),
      area: appointment.area.trim(),
      reason: appointment.reason.trim(),
      patientFirstName: appointment.patientFirstName.trim(),
      patientLastName: appointment.patientLastName.trim(),
      consentVersion: appointment.consentVersion.trim(),
    );
  }

  bool _isSlotAlreadyTaken(
    List<Appointment> items,
    Appointment candidate, {
    String? excludeAppointmentId,
  }) {
    final normalizedCandidate = _normalizeAppointment(candidate);
    final normalizedExcludedId = excludeAppointmentId == null
        ? null
        : _normalizeId(excludeAppointmentId);

    for (final item in items) {
      final normalizedItem = _normalizeAppointment(item);

      if (normalizedExcludedId != null &&
          _normalizeId(normalizedItem.id) == normalizedExcludedId) {
        continue;
      }

      final samePractitioner =
          normalizedItem.practitionerId == normalizedCandidate.practitionerId;
      final sameDay = _isSameDay(normalizedItem.day, normalizedCandidate.day);
      final sameSlot = normalizedItem.slot == normalizedCandidate.slot;
      final isStillBlocking = !normalizedItem.isCancelledLike;

      if (samePractitioner && sameDay && sameSlot && isStillBlocking) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<void> create(Appointment appointment) async {
    final items = await _loadItems();
    final normalizedAppointment = _normalizeAppointment(appointment);

    if (normalizedAppointment.id.isEmpty) {
      return;
    }

    if (_isSlotAlreadyTaken(items, normalizedAppointment)) {
      throw AppointmentSlotUnavailableException(
        practitionerId: normalizedAppointment.practitionerId,
        day: normalizedAppointment.day,
        slot: normalizedAppointment.slot,
      );
    }

    final updated = List<Appointment>.from(items)..add(normalizedAppointment);
    await _persist(updated);
  }

  @override
  Future<AppointmentListResult> list(AppointmentListQuery query) async {
    final items = await _loadItems();
    var filtered = List<Appointment>.from(items);

    final practitionerId = query.practitionerId?.trim();
    if (practitionerId != null && practitionerId.isNotEmpty) {
      final normalizedPractitionerId = _normalizePractitionerId(practitionerId);
      filtered = filtered.where((item) {
        return _normalizePractitionerId(item.practitionerId) ==
            normalizedPractitionerId;
      }).toList();
    }

    if (query.status != null) {
      filtered = filtered.where((item) => item.status == query.status).toList();
    }

    if (query.from != null) {
      final from = query.from!;
      filtered = filtered.where((item) {
        return !item.scheduledAt.isBefore(from);
      }).toList();
    }

    if (query.to != null) {
      final to = query.to!;
      filtered = filtered.where((item) {
        return !item.scheduledAt.isAfter(to);
      }).toList();
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
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) {
      return null;
    }

    final items = await _loadItems();
    for (final item in items) {
      if (_normalizeId(item.id) == normalizedId) {
        return _normalizeAppointment(item);
      }
    }

    return null;
  }

  @override
  Future<void> updateStatus({
    required String id,
    required AppointmentStatus status,
  }) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) {
      return;
    }

    final items = await _loadItems();
    final index = items.indexWhere(
      (item) => _normalizeId(item.id) == normalizedId,
    );
    if (index == -1) {
      return;
    }

    final updated = List<Appointment>.from(items);
    updated[index] = _normalizeAppointment(
      updated[index].copyWith(status: status),
    );
    await _persist(updated);
  }

  @override
  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  }) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) {
      return null;
    }

    final items = await _loadItems();
    final index = items.indexWhere(
      (item) => _normalizeId(item.id) == normalizedId,
    );
    if (index == -1) {
      return null;
    }

    final current = _normalizeAppointment(items[index]);
    if (current.isCancelledLike) {
      return null;
    }

    final candidate = _normalizeAppointment(
      current.copyWith(
        day: _normalizeDay(day),
        slot: _normalizeSlot(slot),
      ),
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