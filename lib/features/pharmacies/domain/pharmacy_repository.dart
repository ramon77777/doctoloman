import 'pharmacy.dart';

abstract class PharmacyRepository {
  Future<List<Pharmacy>> getAll();

  Future<List<Pharmacy>> getOnDuty();

  Future<Pharmacy?> getById(String id);
}