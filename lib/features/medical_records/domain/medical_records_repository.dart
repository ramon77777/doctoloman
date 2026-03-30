import 'medical_record.dart';

abstract class MedicalRecordsRepository {
  Future<List<MedicalRecord>> listAll();

  Future<MedicalRecord?> getById(String id);

  Future<void> create(MedicalRecord record);

  Future<void> update(MedicalRecord record);

  Future<void> deleteById(String id);

  Future<void> clear();
}