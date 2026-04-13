import '../../domain/patient_profile.dart';

abstract class PatientProfileRemoteDataSource {
  Future<PatientProfile?> fetchByPhone(String phone);

  Future<void> save(PatientProfile profile);

  Future<void> clearByPhone(String phone);
}

class FakePatientProfileRemoteDataSource
    implements PatientProfileRemoteDataSource {
  const FakePatientProfileRemoteDataSource();

  @override
  Future<void> clearByPhone(String phone) async {}

  @override
  Future<PatientProfile?> fetchByPhone(String phone) async {
    return null;
  }

  @override
  Future<void> save(PatientProfile profile) async {}
}