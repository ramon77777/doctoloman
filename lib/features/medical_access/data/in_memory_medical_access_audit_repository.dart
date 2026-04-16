import 'medical_access_audit_local_storage.dart';
import '../domain/medical_access_audit.dart';
import '../domain/medical_access_audit_repository.dart';

class InMemoryMedicalAccessAuditRepository
    implements MedicalAccessAuditRepository {
  InMemoryMedicalAccessAuditRepository(this._localStorage);

  final MedicalAccessAuditLocalStorage _localStorage;

  List<MedicalAccessAudit>? _cache;

  Future<List<MedicalAccessAudit>> _loadItems() async {
    _cache ??= await _localStorage.readAll();
    return _cache!;
  }

  Future<void> _persist(List<MedicalAccessAudit> items) async {
    _cache = List<MedicalAccessAudit>.unmodifiable(items);
    await _localStorage.saveAll(_cache!);
  }

  @override
  Future<List<MedicalAccessAudit>> listAll() async {
    final items = await _loadItems();
    final sorted = List<MedicalAccessAudit>.from(items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List<MedicalAccessAudit>.unmodifiable(sorted);
  }

  @override
  Future<void> create(MedicalAccessAudit audit) async {
    final items = await _loadItems();
    final updated = List<MedicalAccessAudit>.from(items)..add(audit);
    await _persist(updated);
  }

  @override
  Future<void> clear() async {
    _cache = <MedicalAccessAudit>[];
    await _localStorage.clear();
  }
}