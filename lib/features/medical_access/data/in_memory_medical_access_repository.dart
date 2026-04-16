import 'medical_access_local_storage.dart';
import '../domain/medical_access.dart';
import '../domain/medical_access_repository.dart';

class InMemoryMedicalAccessRepository implements MedicalAccessRepository {
  InMemoryMedicalAccessRepository(this._localStorage);

  final MedicalAccessLocalStorage _localStorage;

  List<MedicalAccess>? _cache;

  Future<List<MedicalAccess>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<MedicalAccess> items) async {
    _cache = List<MedicalAccess>.unmodifiable(items);
    await _localStorage.saveAll(_cache!);
  }

  String _normalizeId(String value) {
    return value.trim();
  }

  @override
  Future<List<MedicalAccess>> listAll() async {
    final items = await _loadItems();

    final sorted = List<MedicalAccess>.from(items)
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

    return List<MedicalAccess>.unmodifiable(sorted);
  }

  @override
  Future<MedicalAccess?> getById(String id) async {
    final normalizedId = _normalizeId(id);
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
  Future<void> upsert(MedicalAccess access) async {
    final normalizedId = _normalizeId(access.id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final index = items.indexWhere((item) => item.id == normalizedId);

    if (index == -1) {
      final updated = List<MedicalAccess>.from(items)..add(access);
      await _persist(updated);
      return;
    }

    final updated = List<MedicalAccess>.from(items);
    updated[index] = access;
    await _persist(updated);
  }

  @override
  Future<void> revokeById(String id) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final index = items.indexWhere((item) => item.id == normalizedId);
    if (index == -1) return;

    final current = items[index];
    if (!current.isActive) return;

    final updated = List<MedicalAccess>.from(items);
    updated[index] = current.copyWith(
      revokedAt: DateTime.now(),
    );

    await _persist(updated);
  }

  @override
  Future<void> clear() async {
    _cache = <MedicalAccess>[];
    await _localStorage.clear();
  }
}