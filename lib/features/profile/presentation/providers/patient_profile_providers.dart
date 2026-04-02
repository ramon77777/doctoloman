import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/in_memory_patient_profile_repository.dart';
import '../../data/patient_profile_local_storage.dart';
import '../../domain/patient_profile.dart';
import '../../domain/patient_profile_repository.dart';

final patientProfileLocalStorageProvider =
    Provider<PatientProfileLocalStorage>(
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

    final stored = await repo.get();

    if (authUser == null) {
      return null;
    }

    if (stored == null) {
      final createdProfile = PatientProfile(
        id: authUser.id,
        name: authUser.name,
        phone: authUser.phone,
      );
      await repo.save(createdProfile);
      return createdProfile;
    }

    if (stored.id != authUser.id) {
      final createdProfile = PatientProfile(
        id: authUser.id,
        name: authUser.name,
        phone: authUser.phone,
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
    await _repo.clear();
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
  final nextName = authUser.name;
  final nextPhone = authUser.phone;

  final needsNameSync = storedProfile.name != nextName;
  final needsPhoneSync = storedProfile.phone != nextPhone;

  if (!needsNameSync && !needsPhoneSync) {
    return storedProfile;
  }

  return storedProfile.copyWith(
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