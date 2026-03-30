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

final patientProfileProvider = FutureProvider<PatientProfile?>((ref) async {
  final repo = ref.watch(patientProfileRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;

  final stored = await repo.get();

  if (authUser == null) {
    if (stored != null) {
      await repo.clear();
    }
    return null;
  }

  if (stored == null || stored.id != authUser.id) {
    final profile = PatientProfile(
      id: authUser.id,
      name: authUser.name,
      phone: authUser.phone,
    );
    await repo.save(profile);
    return profile;
  }

  final needsSyncFromAuth =
      stored.name != authUser.name || stored.phone != authUser.phone;

  if (needsSyncFromAuth) {
    final synced = stored.copyWith(
      name: authUser.name,
      phone: authUser.phone,
    );
    await repo.save(synced);
    return synced;
  }

  return stored;
}, name: 'patientProfileProvider');

final patientProfileControllerProvider = Provider<PatientProfileController>(
  (ref) {
    final repo = ref.watch(patientProfileRepositoryProvider);
    return PatientProfileController(ref: ref, repo: repo);
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
    _ref.invalidate(patientProfileProvider);
  }

  Future<void> clear() async {
    await _repo.clear();
    _ref.invalidate(patientProfileProvider);
  }
}