import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/in_memory_medical_records_repository.dart';
import '../../data/medical_records_local_storage.dart';
import '../../domain/medical_record.dart';
import '../../domain/medical_records_repository.dart';

final medicalRecordsLocalStorageProvider = Provider<MedicalRecordsLocalStorage>(
  (ref) => MedicalRecordsLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'medicalRecordsLocalStorageProvider',
);

final medicalRecordsRepositoryProvider = Provider<MedicalRecordsRepository>(
  (ref) => InMemoryMedicalRecordsRepository(
    ref.watch(medicalRecordsLocalStorageProvider),
  ),
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
}

class MedicalRecordsFiltersController
    extends StateNotifier<MedicalRecordsFilters> {
  MedicalRecordsFiltersController() : super(MedicalRecordsFilters.initial);

  void setCategory(MedicalRecordCategory? value) {
    if (value == null) {
      state = state.copyWith(clearCategory: true);
      return;
    }
    state = state.copyWith(category: value);
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void clearQuery() {
    state = state.copyWith(query: '');
  }

  void setSortMode(MedicalRecordsSortMode value) {
    state = state.copyWith(sortMode: value);
  }

  void setSensitiveOnly(bool value) {
    state = state.copyWith(sensitiveOnly: value);
  }

  void toggleSensitiveOnly() {
    state = state.copyWith(sensitiveOnly: !state.sensitiveOnly);
  }

  void reset() {
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
    final repo = ref.watch(medicalRecordsRepositoryProvider);
    final items = await repo.listAll();

    final sorted = [...items]
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    return List<MedicalRecord>.unmodifiable(sorted);
  },
  name: 'medicalRecordsListProvider',
);

final filteredMedicalRecordsProvider = Provider<List<MedicalRecord>>(
  (ref) {
    final itemsAsync = ref.watch(medicalRecordsListProvider);
    final filters = ref.watch(medicalRecordsFiltersProvider);

    return itemsAsync.maybeWhen(
      data: (items) {
        var filtered = [...items];

        final normalizedQuery = _normalize(filters.query);
        if (normalizedQuery.isNotEmpty) {
          filtered = filtered.where((item) {
            final haystack = _normalize(
              '${item.title} ${item.sourceLabel} ${item.summary} ${item.patientName}',
            );
            return haystack.contains(normalizedQuery);
          }).toList();
        }

        if (filters.category != null) {
          filtered = filtered
              .where((item) => item.category == filters.category)
              .toList();
        }

        if (filters.sensitiveOnly) {
          filtered = filtered.where((item) => item.isSensitive).toList();
        }

        filtered.sort((a, b) {
          switch (filters.sortMode) {
            case MedicalRecordsSortMode.newestFirst:
              return b.recordDate.compareTo(a.recordDate);
            case MedicalRecordsSortMode.oldestFirst:
              return a.recordDate.compareTo(b.recordDate);
            case MedicalRecordsSortMode.titleAsc:
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
        });

        return List<MedicalRecord>.unmodifiable(filtered);
      },
      orElse: () => const <MedicalRecord>[],
    );
  },
  name: 'filteredMedicalRecordsProvider',
);

final medicalRecordByIdProvider =
    FutureProvider.family<MedicalRecord?, String>((ref, id) async {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  final repo = ref.watch(medicalRecordsRepositoryProvider);
  return repo.getById(normalizedId);
}, name: 'medicalRecordByIdProvider');

final medicalRecordsControllerProvider = Provider<MedicalRecordsController>(
  (ref) {
    final repo = ref.watch(medicalRecordsRepositoryProvider);
    return MedicalRecordsController(ref: ref, repo: repo);
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
    _ref.invalidate(medicalRecordByIdProvider(record.id));
  }

  Future<void> update(MedicalRecord record) async {
    await _repo.update(record);
    _invalidateCollections();
    _ref.invalidate(medicalRecordByIdProvider(record.id));
  }

  Future<void> deleteById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    await _repo.deleteById(normalizedId);
    _invalidateCollections();
    _ref.invalidate(medicalRecordByIdProvider(normalizedId));
  }

  Future<void> clear() async {
    final items = await _repo.listAll();
    await _repo.clear();

    _invalidateCollections();

    for (final item in items) {
      _ref.invalidate(medicalRecordByIdProvider(item.id));
    }
  }

  Future<void> refresh() async {
    _invalidateCollections();
    await _ref.read(medicalRecordsListProvider.future);
  }

  void _invalidateCollections() {
    _ref.invalidate(medicalRecordsListProvider);
  }
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}