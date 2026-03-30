import '../domain/pharmacy.dart';
import '../domain/pharmacy_repository.dart';
import 'mock_pharmacies_data.dart';

class MockPharmacyRepository implements PharmacyRepository {
  const MockPharmacyRepository();

  static const Duration _artificialDelay = Duration(milliseconds: 180);

  @override
  Future<List<Pharmacy>> getAll() async {
    await Future<void>.delayed(_artificialDelay);
    return List<Pharmacy>.unmodifiable(MockPharmaciesData.items());
  }

  @override
  Future<List<Pharmacy>> getOnDuty() async {
    final all = await getAll();
    return List<Pharmacy>.unmodifiable(
      all.where((pharmacy) => pharmacy.isOnDuty),
    );
  }

  @override
  Future<Pharmacy?> getById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;

    final all = await getAll();
    for (final pharmacy in all) {
      if (pharmacy.id == normalizedId) {
        return pharmacy;
      }
    }

    return null;
  }
}