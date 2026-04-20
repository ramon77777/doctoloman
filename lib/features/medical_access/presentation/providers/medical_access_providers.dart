import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../data/in_memory_medical_access_repository.dart';
import '../../data/medical_access_local_storage.dart';
import '../../domain/medical_access.dart';
import '../../domain/medical_access_repository.dart';

final medicalAccessLocalStorageProvider = Provider<MedicalAccessLocalStorage>(
  (ref) => MedicalAccessLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'medicalAccessLocalStorageProvider',
);

final medicalAccessRepositoryProvider = Provider<MedicalAccessRepository>(
  (ref) => InMemoryMedicalAccessRepository(
    ref.watch(medicalAccessLocalStorageProvider),
  ),
  name: 'medicalAccessRepositoryProvider',
);

final medicalAccessListProvider = FutureProvider<List<MedicalAccess>>(
  (ref) async {
    final repo = ref.watch(medicalAccessRepositoryProvider);
    final items = await repo.listAll();

    final sorted = [...items]
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

    return List<MedicalAccess>.unmodifiable(sorted);
  },
  name: 'medicalAccessListProvider',
);

final patientMedicalAccessProvider = Provider<List<MedicalAccess>>(
  (ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final itemsAsync = ref.watch(medicalAccessListProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        if (!authState.isAuthenticated ||
            user == null ||
            user.role != AppUserRole.patient) {
          return const <MedicalAccess>[];
        }

        final patientId = _normalizePatientKey(user.phone);
        if (patientId.isEmpty) {
          return const <MedicalAccess>[];
        }

        final filtered = items.where((item) {
          return item.patientId == patientId && item.isActive;
        }).toList()
          ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

        return List<MedicalAccess>.unmodifiable(filtered);
      },
      orElse: () => const <MedicalAccess>[],
    );
  },
  name: 'patientMedicalAccessProvider',
);

final professionalMedicalAccessProvider = Provider<List<MedicalAccess>>(
  (ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final profile = ref.watch(professionalProfileProvider);
    final itemsAsync = ref.watch(medicalAccessListProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        if (!authState.isAuthenticated ||
            user == null ||
            user.role != AppUserRole.professional) {
          return const <MedicalAccess>[];
        }

        final professionalKeys = _buildProfessionalKeys(
          authUser: user,
          profile: profile,
        );

        if (professionalKeys.isEmpty) {
          return const <MedicalAccess>[];
        }

        final filtered = items.where((item) {
          return item.isActive &&
              professionalKeys.contains(_normalizeTextKey(item.professionalId));
        }).toList()
          ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));

        return List<MedicalAccess>.unmodifiable(filtered);
      },
      orElse: () => const <MedicalAccess>[],
    );
  },
  name: 'professionalMedicalAccessProvider',
);

@immutable
class MedicalAccessQuery {
  const MedicalAccessQuery({
    required this.patientId,
    required this.professionalId,
  });

  final String patientId;
  final String professionalId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MedicalAccessQuery &&
        _normalizePatientCandidate(other.patientId) ==
            _normalizePatientCandidate(patientId) &&
        _normalizeTextKey(other.professionalId) ==
            _normalizeTextKey(professionalId);
  }

  @override
  int get hashCode => Object.hash(
        _normalizePatientCandidate(patientId),
        _normalizeTextKey(professionalId),
      );
}

final hasMedicalAccessProvider =
    Provider.family<bool, MedicalAccessQuery>((ref, query) {
  final itemsAsync = ref.watch(medicalAccessListProvider);
  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;
  final profile = ref.watch(professionalProfileProvider);

  return itemsAsync.maybeWhen(
    data: (items) {
      final patientCandidates = _buildPatientCandidates(query.patientId);
      if (patientCandidates.isEmpty) {
        return false;
      }

      final requestedProfessionalKey = _normalizeTextKey(query.professionalId);

      final professionalKeys = <String>{
        if (requestedProfessionalKey.isNotEmpty) requestedProfessionalKey,
      };

      if (authState.isAuthenticated &&
          authUser != null &&
          authUser.role == AppUserRole.professional) {
        professionalKeys.addAll(
          _buildProfessionalKeys(
            authUser: authUser,
            profile: profile,
          ),
        );
      }

      if (professionalKeys.isEmpty) {
        return false;
      }

      return items.any((item) {
        return item.isActive &&
            patientCandidates.contains(_normalizePatientCandidate(item.patientId)) &&
            professionalKeys.contains(_normalizeTextKey(item.professionalId));
      });
    },
    orElse: () => false,
  );
}, name: 'hasMedicalAccessProvider');

final activeMedicalAccessForCurrentProfessionalByPatientIdProvider =
    Provider.family<MedicalAccess?, String>((ref, patientId) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.user;
  final profile = ref.watch(professionalProfileProvider);

  if (!authState.isAuthenticated ||
      user == null ||
      user.role != AppUserRole.professional) {
    return null;
  }

  final patientCandidates = _buildPatientCandidates(patientId);
  final professionalKeys = _buildProfessionalKeys(
    authUser: user,
    profile: profile,
  );

  if (patientCandidates.isEmpty || professionalKeys.isEmpty) {
    return null;
  }

  final accesses = ref.watch(medicalAccessListProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <MedicalAccess>[],
      );

  for (final access in accesses) {
    if (!access.isActive) continue;

    final accessPatientKey = _normalizePatientCandidate(access.patientId);
    final accessProfessionalKey = _normalizeTextKey(access.professionalId);

    if (patientCandidates.contains(accessPatientKey) &&
        professionalKeys.contains(accessProfessionalKey)) {
      return access;
    }
  }

  return null;
}, name: 'activeMedicalAccessForCurrentProfessionalByPatientIdProvider');

final medicalAccessControllerProvider = Provider<MedicalAccessController>(
  (ref) {
    final repo = ref.watch(medicalAccessRepositoryProvider);
    return MedicalAccessController(
      ref: ref,
      repo: repo,
    );
  },
  name: 'medicalAccessControllerProvider',
);

class MedicalAccessController {
  MedicalAccessController({
    required Ref ref,
    required MedicalAccessRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final MedicalAccessRepository _repo;

  Future<void> grantAccess({
    required AppUser patientUser,
    required String patientName,
    required String professionalId,
    required String professionalName,
  }) async {
    final authState = _ref.read(authControllerProvider);
    final currentUser = authState.user;

    if (!authState.isAuthenticated ||
        currentUser == null ||
        currentUser.role != AppUserRole.patient) {
      return;
    }

    final normalizedCurrentPatientId = _normalizePatientKey(currentUser.phone);
    final normalizedPatientId = _normalizePatientKey(patientUser.phone);
    final normalizedProfessionalId = _normalizeTextKey(professionalId);

    if (normalizedCurrentPatientId.isEmpty ||
        normalizedPatientId.isEmpty ||
        normalizedProfessionalId.isEmpty) {
      return;
    }

    if (normalizedCurrentPatientId != normalizedPatientId) {
      return;
    }

    final existing = await _repo.listAll();
    final match = existing.cast<MedicalAccess?>().firstWhere(
          (item) =>
              item != null &&
              _normalizePatientCandidate(item.patientId) == normalizedPatientId &&
              _normalizeTextKey(item.professionalId) == normalizedProfessionalId,
          orElse: () => null,
        );

    final now = DateTime.now();

    final access = (match == null)
        ? MedicalAccess(
            id: 'ma_${now.microsecondsSinceEpoch}',
            patientId: normalizedPatientId,
            patientName: _fallbackName(patientName, 'Patient'),
            professionalId: normalizedProfessionalId,
            professionalName:
                _fallbackName(professionalName, 'Professionnel'),
            grantedAt: now,
          )
        : match.copyWith(
            patientId: normalizedPatientId,
            patientName: _fallbackName(patientName, match.patientName),
            professionalId: normalizedProfessionalId,
            professionalName:
                _fallbackName(professionalName, match.professionalName),
            grantedAt: now,
            clearRevokedAt: true,
          );

    await _repo.upsert(access);
    _invalidateCollections();
  }

  Future<void> revokeById(String accessId) async {
    final authState = _ref.read(authControllerProvider);
    final currentUser = authState.user;

    if (!authState.isAuthenticated ||
        currentUser == null ||
        currentUser.role != AppUserRole.patient) {
      return;
    }

    final normalizedId = _normalizeTextKey(accessId);
    if (normalizedId.isEmpty) return;

    final existing = await _repo.getById(normalizedId);
    if (existing == null) return;

    final normalizedCurrentPatientId = _normalizePatientKey(currentUser.phone);
    if (_normalizePatientCandidate(existing.patientId) !=
        normalizedCurrentPatientId) {
      return;
    }

    await _repo.revokeById(normalizedId);
    _invalidateCollections();
  }

  Future<void> clear() async {
    final authState = _ref.read(authControllerProvider);
    final currentUser = authState.user;

    if (!authState.isAuthenticated ||
        currentUser == null ||
        currentUser.role != AppUserRole.patient) {
      return;
    }

    final currentPatientId = _normalizePatientKey(currentUser.phone);
    if (currentPatientId.isEmpty) return;

    final items = await _repo.listAll();
    final mine = items.where(
      (item) => _normalizePatientCandidate(item.patientId) == currentPatientId,
    );

    for (final item in mine) {
      if (item.isActive) {
        await _repo.revokeById(item.id);
      }
    }

    _invalidateCollections();
  }

  void _invalidateCollections() {
    _ref.invalidate(medicalAccessListProvider);
    _ref.invalidate(patientMedicalAccessProvider);
    _ref.invalidate(professionalMedicalAccessProvider);
  }
}

Set<String> _buildProfessionalKeys({
  required AppUser authUser,
  required ProfessionalProfile profile,
}) {
  final keys = <String>{
    _normalizeTextKey(authUser.id),
    _normalizeTextKey(profile.id),
  };

  keys.removeWhere((value) => value.isEmpty);
  return keys;
}

Set<String> _buildPatientCandidates(String rawPatientId) {
  final candidates = <String>{
    _normalizePatientCandidate(rawPatientId),
    _normalizePatientKey(rawPatientId),
  };

  candidates.removeWhere((value) => value.isEmpty);
  return candidates;
}

String _normalizePatientKey(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _normalizePatientCandidate(String value) {
  final digits = _normalizePatientKey(value);
  if (digits.isNotEmpty) {
    return digits;
  }
  return _normalizeTextKey(value);
}

String _normalizeTextKey(String value) {
  return value.trim();
}

String _fallbackName(String value, String fallback) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized;
}