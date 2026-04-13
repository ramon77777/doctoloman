import '../../domain/professional_profile.dart';

abstract class ProfessionalProfileRemoteDataSource {
  Future<ProfessionalProfile?> fetchCurrent(String storageKey);

  Future<List<ProfessionalProfile>> fetchAll();

  Future<void> saveCurrent(
    String storageKey,
    ProfessionalProfile profile,
  );

  Future<void> resetCurrent(String storageKey);
}

class FakeProfessionalProfileRemoteDataSource
    implements ProfessionalProfileRemoteDataSource {
  const FakeProfessionalProfileRemoteDataSource();

  @override
  Future<ProfessionalProfile?> fetchCurrent(String storageKey) async {
    return null;
  }

  @override
  Future<List<ProfessionalProfile>> fetchAll() async {
    return const <ProfessionalProfile>[];
  }

  @override
  Future<void> saveCurrent(
    String storageKey,
    ProfessionalProfile profile,
  ) async {}

  @override
  Future<void> resetCurrent(String storageKey) async {}
}