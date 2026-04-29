import '../domain/teleconsultation_repository.dart';
import '../domain/teleconsultation_session.dart';
import 'teleconsultation_local_storage.dart';

class InMemoryTeleconsultationRepository
    implements TeleconsultationRepository {
  InMemoryTeleconsultationRepository(this._localStorage);

  final TeleconsultationLocalStorage _localStorage;

  List<TeleconsultationSession>? _cache;

  Future<List<TeleconsultationSession>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<TeleconsultationSession> items) async {
    final normalized = [...items]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    _cache = List<TeleconsultationSession>.unmodifiable(normalized);
    await _localStorage.writeAll(_cache!);
  }

  @override
  Future<List<TeleconsultationSession>> listAll() async {
    final items = await _loadItems();
    final sorted = [...items]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return List<TeleconsultationSession>.unmodifiable(sorted);
  }

  @override
  Future<TeleconsultationSession?> getById(String id) async {
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
  Future<TeleconsultationSession?> getByAppointmentId(
    String appointmentId,
  ) async {
    final normalizedAppointmentId = appointmentId.trim();
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
  Future<void> upsert(TeleconsultationSession session) async {
    final normalizedId = session.id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Identifiant téléconsultation invalide.');
    }

    final items = [...await _loadItems()];
    final index = items.indexWhere((item) => item.id == normalizedId);

    if (index == -1) {
      items.add(session);
    } else {
      items[index] = session;
    }

    await _persist(items);
  }

  @override
  Future<void> deleteById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    final items = [...await _loadItems()]
      ..removeWhere((item) => item.id == normalizedId);

    await _persist(items);
  }

  @override
  Future<void> clear() async {
    _cache = const <TeleconsultationSession>[];
    await _localStorage.clear();
  }
}