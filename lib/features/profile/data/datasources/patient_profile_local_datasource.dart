import '../patient_profile_local_storage.dart';
import '../../domain/patient_profile.dart';

class PatientProfileLocalDataSource {
  PatientProfileLocalDataSource(this._storage);

  final PatientProfileLocalStorage _storage;

  PatientProfile? readByPhone(String phone) {
    return _storage.readByPhone(phone);
  }

  Map<String, PatientProfile> readAll() {
    return _storage.readAll();
  }

  Future<void> save(PatientProfile profile) {
    return _storage.save(profile);
  }

  Future<void> clearByPhone(String phone) {
    return _storage.clearByPhone(phone);
  }

  Future<void> clear() {
    return _storage.clear();
  }
}