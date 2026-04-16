import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/in_memory_medical_access_audit_repository.dart';
import '../../data/medical_access_audit_local_storage.dart';
import '../../domain/medical_access.dart';
import '../../domain/medical_access_audit.dart';
import '../../domain/medical_access_audit_repository.dart';
import 'medical_access_providers.dart';

final medicalAccessAuditLocalStorageProvider =
    Provider<MedicalAccessAuditLocalStorage>(
  (ref) => MedicalAccessAuditLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'medicalAccessAuditLocalStorageProvider',
);

final medicalAccessAuditRepositoryProvider =
    Provider<MedicalAccessAuditRepository>(
  (ref) => InMemoryMedicalAccessAuditRepository(
    ref.watch(medicalAccessAuditLocalStorageProvider),
  ),
  name: 'medicalAccessAuditRepositoryProvider',
);

final medicalAccessAuditListProvider = FutureProvider<List<MedicalAccessAudit>>(
  (ref) async {
    final repo = ref.watch(medicalAccessAuditRepositoryProvider);
    final items = await repo.listAll();

    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List<MedicalAccessAudit>.unmodifiable(sorted);
  },
  name: 'medicalAccessAuditListProvider',
);

@immutable
class MedicalAccessAuditQuery {
  const MedicalAccessAuditQuery({
    required this.patientId,
    required this.professionalId,
  });

  final String patientId;
  final String professionalId;

  @override
  bool operator ==(Object other) {
    return other is MedicalAccessAuditQuery &&
        _normalizePatientId(other.patientId) == _normalizePatientId(patientId) &&
        _normalizeGenericId(other.professionalId) ==
            _normalizeGenericId(professionalId);
  }

  @override
  int get hashCode => Object.hash(
        _normalizePatientId(patientId),
        _normalizeGenericId(professionalId),
      );
}

final medicalAccessAuditByPatientAndProfessionalProvider =
    Provider.family<List<MedicalAccessAudit>, MedicalAccessAuditQuery>(
  (ref, query) {
    final itemsAsync = ref.watch(medicalAccessAuditListProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        final patientId = _normalizePatientId(query.patientId);
        final professionalId = _normalizeGenericId(query.professionalId);

        if (patientId.isEmpty || professionalId.isEmpty) {
          return const <MedicalAccessAudit>[];
        }

        final filtered = items.where((item) {
          return _normalizePatientId(item.patientId) == patientId &&
              _normalizeGenericId(item.professionalId) == professionalId;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return List<MedicalAccessAudit>.unmodifiable(filtered);
      },
      orElse: () => const <MedicalAccessAudit>[],
    );
  },
  name: 'medicalAccessAuditByPatientAndProfessionalProvider',
);

final medicalAccessAuditControllerProvider =
    Provider<MedicalAccessAuditController>(
  (ref) {
    final repo = ref.watch(medicalAccessAuditRepositoryProvider);
    return MedicalAccessAuditController(
      ref: ref,
      repo: repo,
    );
  },
  name: 'medicalAccessAuditControllerProvider',
);

class MedicalAccessAuditController {
  MedicalAccessAuditController({
    required Ref ref,
    required MedicalAccessAuditRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final MedicalAccessAuditRepository _repo;

  Future<void> logOpenPatientMedicalRecords({
    required String patientId,
    required String patientName,
  }) async {
    final authUser = _ref.read(authControllerProvider).user;
    if (authUser == null) return;

    final professionalId = _normalizeGenericId(authUser.id);
    final professionalName = _fallbackName(authUser.name, 'Professionnel');
    final normalizedPatientId = _normalizePatientId(patientId);

    if (normalizedPatientId.isEmpty || professionalId.isEmpty) return;

    final access = _findMatchingAccess(
      patientId: normalizedPatientId,
      professionalId: professionalId,
    );

    final now = DateTime.now();

    final audit = MedicalAccessAudit(
      id: 'maa_${now.microsecondsSinceEpoch}',
      action: MedicalAccessAuditAction.openPatientMedicalRecords,
      patientId: normalizedPatientId,
      patientName: _fallbackName(patientName, 'Patient'),
      professionalId: professionalId,
      professionalName: professionalName,
      createdAt: now,
      medicalAccessId: access?.id,
    );

    await _repo.create(audit);
    _invalidateCollections();
  }

  Future<void> logOpenMedicalRecord({
    required String patientId,
    required String patientName,
    required String medicalRecordId,
    required String medicalRecordTitle,
  }) async {
    final authUser = _ref.read(authControllerProvider).user;
    if (authUser == null) return;

    final professionalId = _normalizeGenericId(authUser.id);
    final professionalName = _fallbackName(authUser.name, 'Professionnel');

    final normalizedPatientId = _normalizePatientId(patientId);
    final normalizedRecordId = medicalRecordId.trim();

    if (normalizedPatientId.isEmpty ||
        professionalId.isEmpty ||
        normalizedRecordId.isEmpty) {
      return;
    }

    final access = _findMatchingAccess(
      patientId: normalizedPatientId,
      professionalId: professionalId,
    );

    final now = DateTime.now();

    final audit = MedicalAccessAudit(
      id: 'maa_${now.microsecondsSinceEpoch}',
      action: MedicalAccessAuditAction.openMedicalRecord,
      patientId: normalizedPatientId,
      patientName: _fallbackName(patientName, 'Patient'),
      professionalId: professionalId,
      professionalName: professionalName,
      createdAt: now,
      medicalAccessId: access?.id,
      medicalRecordId: normalizedRecordId,
      medicalRecordTitle: _fallbackName(medicalRecordTitle, 'Document'),
    );

    await _repo.create(audit);
    _invalidateCollections();
  }

  Future<void> clear() async {
    await _repo.clear();
    _invalidateCollections();
  }

  MedicalAccess? _findMatchingAccess({
    required String patientId,
    required String professionalId,
  }) {
    final accesses = _ref.read(professionalMedicalAccessProvider);

    for (final access in accesses) {
      if (access.isActive &&
          _normalizePatientId(access.patientId) == patientId &&
          _normalizeGenericId(access.professionalId) == professionalId) {
        return access;
      }
    }

    return null;
  }

  void _invalidateCollections() {
    _ref.invalidate(medicalAccessAuditListProvider);
  }

  String _fallbackName(String value, String fallback) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? fallback : normalized;
  }
}

String _normalizePatientId(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _normalizeGenericId(String value) {
  return value.trim();
}