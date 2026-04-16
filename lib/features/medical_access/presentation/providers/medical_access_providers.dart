import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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

        final patientId = _normalizePatientId(user.phone);
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
    final itemsAsync = ref.watch(medicalAccessListProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        if (!authState.isAuthenticated ||
            user == null ||
            user.role != AppUserRole.professional) {
          return const <MedicalAccess>[];
        }

        final professionalId = _normalizeId(user.id);
        if (professionalId.isEmpty) {
          return const <MedicalAccess>[];
        }

        final filtered = items.where((item) {
          return item.professionalId == professionalId && item.isActive;
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
        _normalizePatientId(other.patientId) == _normalizePatientId(patientId) &&
        _normalizeId(other.professionalId) == _normalizeId(professionalId);
  }

  @override
  int get hashCode => Object.hash(
        _normalizePatientId(patientId),
        _normalizeId(professionalId),
      );
}

final hasMedicalAccessProvider =
    Provider.family<bool, MedicalAccessQuery>((ref, query) {
  final itemsAsync = ref.watch(medicalAccessListProvider);

  return itemsAsync.maybeWhen(
    data: (items) {
      final patientId = _normalizePatientId(query.patientId);
      final professionalId = _normalizeId(query.professionalId);

      if (patientId.isEmpty || professionalId.isEmpty) {
        return false;
      }

      return items.any((item) {
        return item.isActive &&
            item.patientId == patientId &&
            item.professionalId == professionalId;
      });
    },
    orElse: () => false,
  );
}, name: 'hasMedicalAccessProvider');

final activeMedicalAccessForCurrentProfessionalByPatientIdProvider =
    Provider.family<MedicalAccess?, String>((ref, patientId) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.user;

  if (!authState.isAuthenticated ||
      user == null ||
      user.role != AppUserRole.professional) {
    return null;
  }

  final normalizedPatientId = _normalizePatientId(patientId);
  final normalizedProfessionalId = _normalizeId(user.id);

  if (normalizedPatientId.isEmpty || normalizedProfessionalId.isEmpty) {
    return null;
  }

  final accesses = ref.watch(professionalMedicalAccessProvider);

  for (final access in accesses) {
    if (access.isActive &&
        access.patientId == normalizedPatientId &&
        access.professionalId == normalizedProfessionalId) {
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

    final normalizedCurrentPatientId = _normalizePatientId(currentUser.phone);
    final normalizedPatientId = _normalizePatientId(patientUser.phone);
    final normalizedProfessionalId = _normalizeId(professionalId);

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
              item.patientId == normalizedPatientId &&
              item.professionalId == normalizedProfessionalId,
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
            patientName: _fallbackName(patientName, match.patientName),
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

    final normalizedId = _normalizeId(accessId);
    if (normalizedId.isEmpty) return;

    final existing = await _repo.getById(normalizedId);
    if (existing == null) return;

    final normalizedCurrentPatientId = _normalizePatientId(currentUser.phone);
    if (existing.patientId != normalizedCurrentPatientId) {
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

    final currentPatientId = _normalizePatientId(currentUser.phone);
    if (currentPatientId.isEmpty) return;

    final items = await _repo.listAll();
    final mine = items.where((item) => item.patientId == currentPatientId);

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

String _normalizeId(String value) {
  return value.trim();
}

String _normalizePatientId(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _fallbackName(String value, String fallback) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized;
}