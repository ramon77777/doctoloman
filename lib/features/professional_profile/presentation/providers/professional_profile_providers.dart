import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/professional_profile_local_datasource.dart';
import '../../data/datasources/professional_profile_remote_datasource.dart';
import '../../data/professional_profile_local_storage.dart';
import '../../data/repositories/professional_profile_repository_impl.dart';
import '../../domain/professional_profile.dart';
import '../../domain/professional_profile_repository.dart';

final professionalProfileLocalStorageProvider =
    Provider<ProfessionalProfileLocalStorage>(
  (ref) => ProfessionalProfileLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'professionalProfileLocalStorageProvider',
);

final professionalProfileLocalDataSourceProvider =
    Provider<ProfessionalProfileLocalDataSource>(
  (ref) => ProfessionalProfileLocalDataSource(
    ref.watch(professionalProfileLocalStorageProvider),
  ),
  name: 'professionalProfileLocalDataSourceProvider',
);

final professionalProfileRemoteDataSourceProvider =
    Provider<ProfessionalProfileRemoteDataSource>(
  (ref) => const FakeProfessionalProfileRemoteDataSource(),
  name: 'professionalProfileRemoteDataSourceProvider',
);

final professionalProfileRepositoryProvider =
    Provider<ProfessionalProfileRepository>(
  (ref) => ProfessionalProfileRepositoryImpl(
    local: ref.watch(professionalProfileLocalDataSourceProvider),
    remote: ref.watch(professionalProfileRemoteDataSourceProvider),
  ),
  name: 'professionalProfileRepositoryProvider',
);

class ProfessionalProfileController extends StateNotifier<ProfessionalProfile> {
  ProfessionalProfileController(
    this._repository, {
    required AppUser? authUser,
  })  : _authUser = authUser,
        super(_initialState(authUser)) {
    _bootstrap();
  }

  final ProfessionalProfileRepository _repository;
  final AppUser? _authUser;

  static ProfessionalProfile _initialState(AppUser? authUser) {
    if (authUser == null || !authUser.isProfessional) {
      return defaultProfessionalProfile;
    }

    return _buildDefaultProfileForAuthUser(authUser);
  }

  Future<void> _bootstrap() async {
    final profile = await _repository.getCurrent(
      currentUserId: _authUser?.id,
      currentUserName: _authUser?.name,
      currentUserPhone: _authUser?.phone,
      isProfessional: _authUser?.isProfessional ?? false,
    );

    state = profile;
  }

  Future<void> updateProfile({
    required String displayName,
    required String specialty,
    required String structureName,
    required String phone,
    required String city,
    required String area,
    required String address,
    required String bio,
    required List<String> languages,
    required String consultationFeeLabel,
    required bool isVerified,
  }) async {
    final nextState = state.copyWith(
      displayName: displayName,
      specialty: specialty,
      structureName: structureName,
      phone: phone,
      city: city,
      area: area,
      address: address,
      bio: bio,
      languages: languages,
      consultationFeeLabel: consultationFeeLabel,
      isVerified: isVerified,
    );

    if (nextState == state) return;

    state = nextState;
    await _repository.saveCurrent(
      nextState,
      currentUserId: _authUser?.id,
      currentUserName: _authUser?.name,
      currentUserPhone: _authUser?.phone,
      isProfessional: _authUser?.isProfessional ?? false,
    );
  }

  Future<void> resetProfile() async {
    await _repository.resetCurrent(
      currentUserId: _authUser?.id,
      currentUserName: _authUser?.name,
      currentUserPhone: _authUser?.phone,
      isProfessional: _authUser?.isProfessional ?? false,
    );

    state = await _repository.getCurrent(
      currentUserId: _authUser?.id,
      currentUserName: _authUser?.name,
      currentUserPhone: _authUser?.phone,
      isProfessional: _authUser?.isProfessional ?? false,
    );
  }

  Future<void> replaceProfile(ProfessionalProfile profile) async {
    if (profile == state) return;

    state = profile;
    await _repository.saveCurrent(
      profile,
      currentUserId: _authUser?.id,
      currentUserName: _authUser?.name,
      currentUserPhone: _authUser?.phone,
      isProfessional: _authUser?.isProfessional ?? false,
    );
  }
}

ProfessionalProfile _buildDefaultProfileForAuthUser(AppUser user) {
  final digits = user.phone.replaceAll(RegExp(r'\D'), '');
  final suffix =
      digits.length >= 4 ? digits.substring(digits.length - 4) : '0000';

  final fallbackName = user.name.trim().isEmpty ||
          user.name.trim().toLowerCase() == 'utilisateur' ||
          user.name.trim().toLowerCase() == 'nouveau professionnel'
      ? 'Professionnel $suffix'
      : user.name.trim();

  return ProfessionalProfile(
    id: user.id.trim().isEmpty ? 'pro_$suffix' : user.id.trim(),
    displayName: fallbackName,
    specialty: 'Professionnel de santé',
    structureName: '',
    phone: user.phone,
    city: '',
    area: '',
    address: '',
    bio: '',
    languages: const ['Français'],
    consultationFeeLabel: '',
    isVerified: false,
  );
}

final professionalProfileProvider =
    StateNotifierProvider<ProfessionalProfileController, ProfessionalProfile>(
  (ref) {
    final repository = ref.watch(professionalProfileRepositoryProvider);
    final authUser = ref.watch(authControllerProvider).user;

    return ProfessionalProfileController(
      repository,
      authUser: authUser,
    );
  },
  name: 'professionalProfileProvider',
);

final allProfessionalProfilesProvider = FutureProvider<List<ProfessionalProfile>>(
  (ref) async {
    final repository = ref.watch(professionalProfileRepositoryProvider);
    return repository.getAll();
  },
  name: 'allProfessionalProfilesProvider',
);