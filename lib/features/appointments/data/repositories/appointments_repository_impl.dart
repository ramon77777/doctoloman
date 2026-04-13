import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';
import '../datasources/appointments_local_datasource.dart';
import '../datasources/appointments_remote_datasource.dart';

class AppointmentsRepositoryImpl implements AppointmentsRepository {
  AppointmentsRepositoryImpl({
    required AppointmentsLocalDataSource local,
    required AppointmentsRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final AppointmentsLocalDataSource _local;
  final AppointmentsRemoteDataSource _remote;

  List<Appointment>? _cache;

  Future<List<Appointment>> _loadItems() async {
    _cache ??= await _local.readAll();
    return _cache!;
  }

  Future<void> _persist(List<Appointment> items) async {
    _cache = List<Appointment>.unmodifiable(items);
    await _local.replaceAll(_cache!);
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
    if (trimmed.isEmpty) return '';

    final parts = trimmed.split(':');
    if (parts.length != 2) return trimmed;

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
      practitionerId: _normalizePractitionerId(appointment.practitionerId),
      day: _normalizeDay(appointment.day),
      slot: _normalizeSlot(appointment.slot),
    );
  }

  bool _isSlotAlreadyTaken(
    List<Appointment> items,
    Appointment candidate, {
    String? excludeAppointmentId,
  }) {
    final normalizedCandidate = _normalizeAppointment(candidate);

    for (final item in items) {
      if (excludeAppointmentId != null && item.id == excludeAppointmentId) {
        continue;
      }

      final normalizedItem = _normalizeAppointment(item);

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

    if (_isSlotAlreadyTaken(items, normalizedAppointment)) {
      throw AppointmentSlotUnavailableException(
        practitionerId: normalizedAppointment.practitionerId,
        day: normalizedAppointment.day,
        slot: normalizedAppointment.slot,
      );
    }

    final created = await _remote.create(normalizedAppointment);

    final updated = List<Appointment>.from(items)..add(created);
    await _persist(updated);
  }

  @override
  Future<AppointmentListResult> list(AppointmentListQuery query) async {
    return _local.list(query);
  }

  @override
  Future<Appointment?> getById(String id) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) return null;

    final local = await _local.getById(normalizedId);
    if (local != null) {
      return local;
    }

    return _remote.getById(normalizedId);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required AppointmentStatus status,
  }) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final index =
        items.indexWhere((item) => _normalizeId(item.id) == normalizedId);
    if (index == -1) return;

    final current = items[index];
    final remoteUpdated = await _remote.updateStatus(
      id: normalizedId,
      status: status,
    );

    final next = remoteUpdated ?? current.copyWith(status: status);

    final updated = List<Appointment>.from(items);
    updated[index] = _normalizeAppointment(next);
    await _persist(updated);
  }

  @override
  Future<Appointment?> reschedule({
    required String id,
    required DateTime day,
    required String slot,
  }) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) return null;

    final items = await _loadItems();
    final index =
        items.indexWhere((item) => _normalizeId(item.id) == normalizedId);
    if (index == -1) return null;

    final current = items[index];
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

    final remoteUpdated = await _remote.reschedule(
      id: normalizedId,
      day: candidate.day,
      slot: candidate.slot,
    );

    final resolved = remoteUpdated ?? candidate;

    final updated = List<Appointment>.from(items);
    updated[index] = _normalizeAppointment(resolved);
    await _persist(updated);

    return resolved;
  }

  @override
  Future<void> clear() async {
    _cache = <Appointment>[];
    await _remote.clear();
    await _local.clear();
  }
}