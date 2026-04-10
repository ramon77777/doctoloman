import '../domain/patient_profile.dart';
import '../domain/patient_profile_repository.dart';
import 'patient_profile_local_storage.dart';

class InMemoryPatientProfileRepository implements PatientProfileRepository {
  InMemoryPatientProfileRepository(this._localStorage);

  final PatientProfileLocalStorage _localStorage;

  final Map<String, PatientProfile?> _cacheByPhone =
      <String, PatientProfile?>{};

  Future<PatientProfile?> _loadCachedOrStored(String phone) async {
    final normalizedPhone = _normalizePhoneKey(phone);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    if (_cacheByPhone.containsKey(normalizedPhone)) {
      return _cacheByPhone[normalizedPhone];
    }

    final stored = _localStorage.readByPhone(phone);
    _cacheByPhone[normalizedPhone] = stored;
    return stored;
  }

  @override
  Future<PatientProfile?> get({String? phone}) async {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    return _loadCachedOrStored(phone);
  }

  @override
  Future<void> save(PatientProfile profile) async {
    final normalizedPhone = _normalizePhoneKey(profile.phone);
    if (normalizedPhone.isEmpty) {
      return;
    }

    _cacheByPhone[normalizedPhone] = profile;
    await _localStorage.save(profile);
  }

  @override
  Future<void> clear({String? phone}) async {
    if (phone == null || phone.trim().isEmpty) {
      _cacheByPhone.clear();
      await _localStorage.clear();
      return;
    }

    final normalizedPhone = _normalizePhoneKey(phone);
    _cacheByPhone.remove(normalizedPhone);
    await _localStorage.clearByPhone(phone);
  }

  String _normalizePhoneKey(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}