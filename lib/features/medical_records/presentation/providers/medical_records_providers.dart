import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../medical_access/presentation/providers/medical_access_providers.dart';
import '../../data/in_memory_medical_records_repository.dart';
import '../../data/medical_records_local_storage.dart';
import '../../domain/medical_record.dart';
import '../../domain/medical_records_repository.dart';

final medicalRecordsLocalStorageProvider =
    Provider<MedicalRecordsLocalStorage>(
  (ref) => MedicalRecordsLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'medicalRecordsLocalStorageProvider',
);

final medicalRecordsRepositoryProvider =
    Provider<MedicalRecordsRepository>(
  (ref) {
    final authUser = ref.watch(authControllerProvider).user;
    final patientKey = _normalizePatientStorageKey(authUser?.phone ?? '');

    return InMemoryMedicalRecordsRepository(
      ref.watch(medicalRecordsLocalStorageProvider),
      patientKey: patientKey,
    );
  },
  name: 'medicalRecordsRepositoryProvider',
);

enum MedicalRecordsSortMode {
  newestFirst,
  oldestFirst,
  titleAsc,
}

@immutable
class MedicalRecordsFilters {
  const MedicalRecordsFilters({
    required this.category,
    required this.query,
    required this.sortMode,
    required this.sensitiveOnly,
  });

  final MedicalRecordCategory? category;
  final String query;
  final MedicalRecordsSortMode sortMode;
  final bool sensitiveOnly;

  MedicalRecordsFilters copyWith({
    MedicalRecordCategory? category,
    bool clearCategory = false,
    String? query,
    MedicalRecordsSortMode? sortMode,
    bool? sensitiveOnly,
  }) {
    return MedicalRecordsFilters(
      category: clearCategory ? null : (category ?? this.category),
      query: query ?? this.query,
      sortMode: sortMode ?? this.sortMode,
      sensitiveOnly: sensitiveOnly ?? this.sensitiveOnly,
    );
  }

  static const initial = MedicalRecordsFilters(
    category: null,
    query: '',
    sortMode: MedicalRecordsSortMode.newestFirst,
    sensitiveOnly: false,
  );

  @override
  bool operator ==(Object other) {
    return other is MedicalRecordsFilters &&
        other.category == category &&
        other.query == query &&
        other.sortMode == sortMode &&
        other.sensitiveOnly == sensitiveOnly;
  }

  @override
  int get hashCode => Object.hash(
        category,
        query,
        sortMode,
        sensitiveOnly,
      );
}

class MedicalRecordsFiltersController
    extends StateNotifier<MedicalRecordsFilters> {
  MedicalRecordsFiltersController()
      : super(MedicalRecordsFilters.initial);

  void setCategory(MedicalRecordCategory? value) {
    if (value == null) {
      if (state.category == null) return;
      state = state.copyWith(clearCategory: true);
      return;
    }

    if (state.category == value) return;
    state = state.copyWith(category: value);
  }

  void setQuery(String value) {
    final normalized = _normalizeQuery(value);
    if (state.query == normalized) return;
    state = state.copyWith(query: normalized);
  }

  void clearQuery() {
    if (state.query.isEmpty) return;
    state = state.copyWith(query: '');
  }

  void setSortMode(MedicalRecordsSortMode value) {
    if (state.sortMode == value) return;
    state = state.copyWith(sortMode: value);
  }

  void setSensitiveOnly(bool value) {
    if (state.sensitiveOnly == value) return;
    state = state.copyWith(sensitiveOnly: value);
  }

  void toggleSensitiveOnly() {
    state = state.copyWith(sensitiveOnly: !state.sensitiveOnly);
  }

  void reset() {
    if (state == MedicalRecordsFilters.initial) return;
    state = MedicalRecordsFilters.initial;
  }
}

final medicalRecordsFiltersProvider = StateNotifierProvider<
    MedicalRecordsFiltersController, MedicalRecordsFilters>(
  (ref) => MedicalRecordsFiltersController(),
  name: 'medicalRecordsFiltersProvider',
);

final medicalRecordsListProvider = FutureProvider<List<MedicalRecord>>(
  (ref) async {
    final authState = ref.watch(authControllerProvider);
    final authUser = authState.user;

    if (!authState.isAuthenticated ||
        authUser == null ||
        authUser.role != AppUserRole.patient) {
      return const <MedicalRecord>[];
    }

    final repo = ref.watch(medicalRecordsRepositoryProvider);
    final items = await repo.listAll();

    final sorted = [...items]
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    return List<MedicalRecord>.unmodifiable(sorted);
  },
  name: 'medicalRecordsListProvider',
);

final medicalRecordsByPatientIdProvider =
    FutureProvider.family<List<MedicalRecord>, String>((ref, patientId) async {
  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;

  if (!authState.isAuthenticated || authUser == null) {
    return const <MedicalRecord>[];
  }

  final normalizedPatientId = _normalizePatientStorageKey(patientId);
  if (normalizedPatientId.isEmpty) {
    return const <MedicalRecord>[];
  }

  if (authUser.role == AppUserRole.patient) {
    final currentPatientId = _normalizePatientStorageKey(authUser.phone);
    if (currentPatientId.isEmpty || currentPatientId != normalizedPatientId) {
      return const <MedicalRecord>[];
    }
  } else if (authUser.role == AppUserRole.professional) {
    final access = ref.watch(
      activeMedicalAccessForCurrentProfessionalByPatientIdProvider(
        normalizedPatientId,
      ),
    );

    if (access == null || !access.isActive) {
      return const <MedicalRecord>[];
    }
  } else {
    return const <MedicalRecord>[];
  }

  final localStorage = ref.watch(medicalRecordsLocalStorageProvider);
  final repo = InMemoryMedicalRecordsRepository(
    localStorage,
    patientKey: normalizedPatientId,
  );

  final items = await repo.listAll();
  final sorted = [...items]
    ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

  return List<MedicalRecord>.unmodifiable(sorted);
}, name: 'medicalRecordsByPatientIdProvider');

final filteredMedicalRecordsProvider = Provider<List<MedicalRecord>>(
  (ref) {
    final itemsAsync = ref.watch(medicalRecordsListProvider);
    final filters = ref.watch(medicalRecordsFiltersProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        var filtered = [...items];

        if (filters.query.isNotEmpty) {
          filtered = filtered.where(
            (item) => _matchesMedicalRecordQuery(
              item: item,
              query: filters.query,
            ),
          ).toList();
        }

        if (filters.category != null) {
          filtered = filtered
              .where((item) => item.category == filters.category)
              .toList();
        }

        if (filters.sensitiveOnly) {
          filtered = filtered.where((item) => item.isSensitive).toList();
        }

        filtered.sort(
          (a, b) => _compareMedicalRecords(
            a: a,
            b: b,
            sortMode: filters.sortMode,
          ),
        );

        return List<MedicalRecord>.unmodifiable(filtered);
      },
      orElse: () => const <MedicalRecord>[],
    );
  },
  name: 'filteredMedicalRecordsProvider',
);

final medicalRecordByIdProvider =
    FutureProvider.family<MedicalRecord?, String>((ref, id) async {
  final authState = ref.watch(authControllerProvider);
  final authUser = authState.user;

  if (!authState.isAuthenticated ||
      authUser == null ||
      authUser.role != AppUserRole.patient) {
    return null;
  }

  final normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  final repo = ref.watch(medicalRecordsRepositoryProvider);
  return repo.getById(normalizedId);
}, name: 'medicalRecordByIdProvider');

final medicalRecordsControllerProvider =
    Provider<MedicalRecordsController>(
  (ref) {
    final repo = ref.watch(medicalRecordsRepositoryProvider);
    return MedicalRecordsController(
      ref: ref,
      repo: repo,
    );
  },
  name: 'medicalRecordsControllerProvider',
);

class MedicalRecordsController {
  MedicalRecordsController({
    required Ref ref,
    required MedicalRecordsRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final MedicalRecordsRepository _repo;

  Future<void> create(MedicalRecord record) async {
    await _repo.create(record);
    _invalidateCollections();
    _invalidateRecord(record.id);
    _invalidatePatientCollection(record.patientId);
  }

  Future<void> update(MedicalRecord record) async {
    await _repo.update(record);
    _invalidateCollections();
    _invalidateRecord(record.id);
    _invalidatePatientCollection(record.patientId);
  }

  Future<void> deleteById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    final existing = await _repo.getById(normalizedId);

    await _repo.deleteById(normalizedId);
    _invalidateCollections();
    _invalidateRecord(normalizedId);

    if (existing != null) {
      _invalidatePatientCollection(existing.patientId);
    }
  }

  Future<void> clear() async {
    final items = await _repo.listAll();
    await _repo.clear();

    _invalidateCollections();

    for (final item in items) {
      _invalidateRecord(item.id);
      _invalidatePatientCollection(item.patientId);
    }
  }

  Future<void> refresh() async {
    _invalidateCollections();
    await _ref.read(medicalRecordsListProvider.future);
  }

  void _invalidateCollections() {
    _ref.invalidate(medicalRecordsListProvider);
    _ref.invalidate(filteredMedicalRecordsProvider);
  }

  void _invalidateRecord(String id) {
    _ref.invalidate(medicalRecordByIdProvider(id));
  }

  void _invalidatePatientCollection(String patientId) {
    final normalizedPatientId = patientId.trim();
    if (normalizedPatientId.isEmpty) return;
    _ref.invalidate(medicalRecordsByPatientIdProvider(normalizedPatientId));
  }
}

bool _matchesMedicalRecordQuery({
  required MedicalRecord item,
  required String query,
}) {
  if (query.isEmpty) return true;

  final haystack = _normalizeSearch(
    '${item.title} '
    '${item.sourceLabel} '
    '${item.summary} '
    '${item.patientName}',
  );

  return haystack.contains(query);
}

int _compareMedicalRecords({
  required MedicalRecord a,
  required MedicalRecord b,
  required MedicalRecordsSortMode sortMode,
}) {
  switch (sortMode) {
    case MedicalRecordsSortMode.newestFirst:
      return b.recordDate.compareTo(a.recordDate);
    case MedicalRecordsSortMode.oldestFirst:
      return a.recordDate.compareTo(b.recordDate);
    case MedicalRecordsSortMode.titleAsc:
      final byTitle =
          a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (byTitle != 0) return byTitle;
      return b.recordDate.compareTo(a.recordDate);
  }
}

String _normalizeQuery(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizePatientStorageKey(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}