import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/string_normalizers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/in_memory_patient_profile_repository.dart';
import '../../data/patient_profile_local_storage.dart';
import '../../domain/patient_profile.dart';
import '../../domain/patient_profile_repository.dart';

final patientProfileLocalStorageProvider = Provider<PatientProfileLocalStorage>(
  (ref) => PatientProfileLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'patientProfileLocalStorageProvider',
);

final patientProfileRepositoryProvider = Provider<PatientProfileRepository>(
  (ref) => InMemoryPatientProfileRepository(
    ref.watch(patientProfileLocalStorageProvider),
  ),
  name: 'patientProfileRepositoryProvider',
);

final patientProfileProvider = FutureProvider<PatientProfile?>(
  (ref) async {
    final repo = ref.watch(patientProfileRepositoryProvider);
    final authState = ref.watch(authControllerProvider);
    final authUser = authState.user;

    if (authUser == null) {
      return null;
    }

    final authPhone = authUser.phone.trim();
    final authPhoneKey = _normalizePhoneKey(authPhone);

    final stored = await repo.get(phone: authPhone);

    if (stored == null) {
      final createdProfile = PatientProfile(
        id: authUser.id,
        name: _effectiveAuthName(authUser.name),
        phone: authPhone,
      );
      await repo.save(createdProfile);
      return createdProfile;
    }

    final storedPhoneKey = _normalizePhoneKey(stored.phone);

    final isSameUserById =
        stored.id.trim().isNotEmpty && stored.id.trim() == authUser.id.trim();

    final isSameUserByPhone =
        storedPhoneKey.isNotEmpty && storedPhoneKey == authPhoneKey;

    if (!isSameUserById && !isSameUserByPhone) {
      final createdProfile = PatientProfile(
        id: authUser.id,
        name: _effectiveAuthName(authUser.name),
        phone: authPhone,
      );
      await repo.save(createdProfile);
      return createdProfile;
    }

    final syncedProfile = _syncProfileWithAuth(
      storedProfile: stored,
      authUser: authUser,
    );

    if (!_samePatientProfile(stored, syncedProfile)) {
      await repo.save(syncedProfile);
      return syncedProfile;
    }

    return stored;
  },
  name: 'patientProfileProvider',
);

final patientProfileControllerProvider = Provider<PatientProfileController>(
  (ref) {
    final repo = ref.watch(patientProfileRepositoryProvider);
    return PatientProfileController(
      ref: ref,
      repo: repo,
    );
  },
  name: 'patientProfileControllerProvider',
);

class PatientProfileController {
  PatientProfileController({
    required Ref ref,
    required PatientProfileRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final PatientProfileRepository _repo;

  Future<void> save(PatientProfile profile) async {
    await _repo.save(profile);
    _invalidateProfile();
  }

  Future<void> clear() async {
    final authUser = _ref.read(authControllerProvider).user;
    await _repo.clear(phone: authUser?.phone);
    _invalidateProfile();
  }

  void _invalidateProfile() {
    _ref.invalidate(patientProfileProvider);
  }
}

PatientProfile _syncProfileWithAuth({
  required PatientProfile storedProfile,
  required dynamic authUser,
}) {
  final nextId = authUser.id;
  final nextPhone = authUser.phone;

  final storedName = storedProfile.name.trim();
  final authName = (authUser.name ?? '').toString().trim();

  final shouldKeepStoredName =
      _isPlaceholderName(authName) && storedName.isNotEmpty;

  final nextName =
      shouldKeepStoredName ? storedName : _effectiveAuthName(authName);

  final needsIdSync = storedProfile.id != nextId;
  final needsNameSync = storedProfile.name != nextName;
  final needsPhoneSync =
      _normalizePhoneKey(storedProfile.phone) != _normalizePhoneKey(nextPhone);

  if (!needsIdSync && !needsNameSync && !needsPhoneSync) {
    return storedProfile;
  }

  return storedProfile.copyWith(
    id: nextId,
    name: nextName,
    phone: nextPhone,
  );
}

bool _samePatientProfile(PatientProfile a, PatientProfile b) {
  return a.id == b.id &&
      a.name == b.name &&
      a.phone == b.phone &&
      a.city == b.city &&
      a.district == b.district &&
      a.address == b.address &&
      a.birthDate == b.birthDate &&
      a.gender == b.gender &&
      a.bloodGroup == b.bloodGroup &&
      a.allergies == b.allergies &&
      a.medicalNotes == b.medicalNotes &&
      a.emergencyContactName == b.emergencyContactName &&
      a.emergencyContactPhone == b.emergencyContactPhone;
}

String _normalizePhoneKey(String value) {
  return StringNormalizers.normalizePhoneCi(value)
      .replaceAll(RegExp(r'\D'), '');
}

bool _isPlaceholderName(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'utilisateur' ||
      normalized == 'nouveau patient';
}

String _effectiveAuthName(String value) {
  final normalized = value.trim();
  if (_isPlaceholderName(normalized)) {
    return 'Utilisateur';
  }
  return normalized;
}