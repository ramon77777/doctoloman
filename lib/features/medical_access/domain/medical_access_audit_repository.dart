import 'medical_access_audit.dart';

abstract class MedicalAccessAuditRepository {
  Future<List<MedicalAccessAudit>> listAll();

  Future<void> create(MedicalAccessAudit audit);

  Future<void> clear();
}