import '../../../../core/utils/string_normalizers.dart';
import '../../domain/patient_profile.dart';
import '../../domain/patient_profile_repository.dart';
import '../datasources/patient_profile_local_datasource.dart';
import '../datasources/patient_profile_remote_datasource.dart';

class PatientProfileRepositoryImpl implements PatientProfileRepository {
  PatientProfileRepositoryImpl({
    required PatientProfileLocalDataSource local,
    required PatientProfileRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final PatientProfileLocalDataSource _local;
  final PatientProfileRemoteDataSource _remote;

  final Map<String, PatientProfile?> _cacheByPhone = <String, PatientProfile?>{};

  @override
  Future<PatientProfile?> get({String? phone}) async {
    final normalizedPhone = _normalizePhoneKey(phone ?? '');
    if (normalizedPhone.isEmpty) {
      return null;
    }

    if (_cacheByPhone.containsKey(normalizedPhone)) {
      return _cacheByPhone[normalizedPhone];
    }

    final localProfile = _local.readByPhone(phone!);
    if (localProfile != null) {
      _cacheByPhone[normalizedPhone] = localProfile;
      return localProfile;
    }

    final remoteProfile = await _remote.fetchByPhone(phone);
    if (remoteProfile != null) {
      _cacheByPhone[normalizedPhone] = remoteProfile;
      await _local.save(remoteProfile);
      return remoteProfile;
    }

    _cacheByPhone[normalizedPhone] = null;
    return null;
  }

  @override
  Future<void> save(PatientProfile profile) async {
    final normalizedPhone = _normalizePhoneKey(profile.phone);
    if (normalizedPhone.isEmpty) {
      return;
    }

    _cacheByPhone[normalizedPhone] = profile;
    await _remote.save(profile);
    await _local.save(profile);
  }

  @override
  Future<void> clear({String? phone}) async {
    if (phone == null || phone.trim().isEmpty) {
      _cacheByPhone.clear();
      await _local.clear();
      return;
    }

    final normalizedPhone = _normalizePhoneKey(phone);
    _cacheByPhone.remove(normalizedPhone);

    await _remote.clearByPhone(phone);
    await _local.clearByPhone(phone);
  }
}

String _normalizePhoneKey(String value) {
  return StringNormalizers.normalizePhoneCi(value)
      .replaceAll(RegExp(r'\D'), '');
}