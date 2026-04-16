import 'medical_access.dart';

abstract class MedicalAccessRepository {
  Future<List<MedicalAccess>> listAll();

  Future<MedicalAccess?> getById(String id);

  Future<void> upsert(MedicalAccess access);

  Future<void> revokeById(String id);

  Future<void> clear();
}