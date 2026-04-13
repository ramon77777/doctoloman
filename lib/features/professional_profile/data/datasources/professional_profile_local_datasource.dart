import '../professional_profile_local_storage.dart';

class ProfessionalProfileLocalDataSource {
  ProfessionalProfileLocalDataSource(this._storage);

  final ProfessionalProfileLocalStorage _storage;

  Map<String, dynamic> readProfilesMap() {
    return _storage.readProfilesMap();
  }

  Future<void> writeProfilesMap(Map<String, dynamic> profilesMap) {
    return _storage.writeProfilesMap(profilesMap);
  }

  Future<void> clear() {
    return _storage.clear();
  }
}