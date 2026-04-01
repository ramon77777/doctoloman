import 'medical_records_local_storage.dart';
import '../domain/medical_record.dart';
import '../domain/medical_records_repository.dart';

class InMemoryMedicalRecordsRepository implements MedicalRecordsRepository {
  InMemoryMedicalRecordsRepository(this._localStorage);

  final MedicalRecordsLocalStorage _localStorage;

  List<MedicalRecord>? _cache;

  Future<List<MedicalRecord>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<MedicalRecord> items) async {
    _cache = List<MedicalRecord>.unmodifiable(items);
    await _localStorage.saveAll(_cache!);
  }

  String _normalizeId(String value) {
    return value.trim();
  }

  @override
  Future<List<MedicalRecord>> listAll() async {
    final items = await _loadItems();

    final copy = List<MedicalRecord>.from(items)
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    return List<MedicalRecord>.unmodifiable(copy);
  }

  @override
  Future<MedicalRecord?> getById(String id) async {
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
  Future<void> create(MedicalRecord record) async {
    final items = await _loadItems();
    final updated = List<MedicalRecord>.from(items)..add(record);
    await _persist(updated);
  }

  @override
  Future<void> update(MedicalRecord record) async {
    final normalizedId = _normalizeId(record.id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final index = items.indexWhere((item) => item.id == normalizedId);
    if (index == -1) return;

    final updated = List<MedicalRecord>.from(items);
    updated[index] = record;
    await _persist(updated);
  }

  @override
  Future<void> deleteById(String id) async {
    final normalizedId = _normalizeId(id);
    if (normalizedId.isEmpty) return;

    final items = await _loadItems();
    final updated = items.where((item) => item.id != normalizedId).toList();
    await _persist(updated);
  }

  @override
  Future<void> clear() async {
    _cache = <MedicalRecord>[];
    await _localStorage.clear();
  }
}