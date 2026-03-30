import '../domain/patient_profile.dart';
import '../domain/patient_profile_repository.dart';
import 'patient_profile_local_storage.dart';

class InMemoryPatientProfileRepository implements PatientProfileRepository {
  InMemoryPatientProfileRepository(this._localStorage);

  final PatientProfileLocalStorage _localStorage;

  PatientProfile? _cache;

  @override
  Future<PatientProfile?> get() async {
    _cache ??= _localStorage.read();
    return _cache;
  }

  @override
  Future<void> save(PatientProfile profile) async {
    _cache = profile;
    await _localStorage.save(profile);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _localStorage.clear();
  }
}