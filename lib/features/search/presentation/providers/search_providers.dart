import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../data/mock_search_data.dart';
import '../../data/mock_search_repository.dart';
import '../../domain/practitioner_search_resolver.dart';
import '../../domain/search_item.dart';
import '../../domain/search_repository.dart';

enum SortMode {
  recommended,
  ratingDesc,
  priceAsc,
  priceDesc,
  distanceAsc,
}

@immutable
class SearchFilters {
  const SearchFilters({
    required this.what,
    required this.where,
    required this.availableSoonOnly,
    required this.city,
    required this.sortMode,
  });

  final String what;
  final String where;
  final bool availableSoonOnly;
  final String? city;
  final SortMode sortMode;

  SearchFilters copyWith({
    String? what,
    String? where,
    bool? availableSoonOnly,
    String? city,
    bool clearCity = false,
    SortMode? sortMode,
  }) {
    return SearchFilters(
      what: what ?? this.what,
      where: where ?? this.where,
      availableSoonOnly: availableSoonOnly ?? this.availableSoonOnly,
      city: clearCity ? null : (city ?? this.city),
      sortMode: sortMode ?? this.sortMode,
    );
  }

  static SearchFilters initial({
    required String what,
    required String where,
  }) {
    return SearchFilters(
      what: _normalizeSearchText(what),
      where: _normalizeSearchText(where),
      availableSoonOnly: false,
      city: null,
      sortMode: SortMode.recommended,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchFilters &&
        other.what == what &&
        other.where == where &&
        other.availableSoonOnly == availableSoonOnly &&
        other.city == city &&
        other.sortMode == sortMode;
  }

  @override
  int get hashCode =>
      Object.hash(what, where, availableSoonOnly, city, sortMode);
}

@immutable
class SearchSeed {
  const SearchSeed({
    required this.initialWhat,
    required this.initialWhere,
  });

  final String initialWhat;
  final String initialWhere;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchSeed &&
        other.initialWhat == initialWhat &&
        other.initialWhere == initialWhere;
  }

  @override
  int get hashCode => Object.hash(initialWhat, initialWhere);
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => const MockSearchRepository(),
  name: 'searchRepositoryProvider',
);

class SearchFiltersController extends StateNotifier<SearchFilters> {
  SearchFiltersController(SearchFilters filters) : super(filters);

  void setWhat(String value) {
    final normalized = _normalizeSearchText(value);
    if (normalized == state.what) return;
    state = state.copyWith(what: normalized);
  }

  void setWhere(String value) {
    final normalized = _normalizeSearchText(value);
    if (normalized == state.where) return;
    state = state.copyWith(where: normalized);
  }

  void setAvailableSoonOnly(bool value) {
    if (value == state.availableSoonOnly) return;
    state = state.copyWith(availableSoonOnly: value);
  }

  void toggleAvailableSoon() {
    state = state.copyWith(
      availableSoonOnly: !state.availableSoonOnly,
    );
  }

  void setCity(String? value) {
    final normalized = _normalizeOptionalFilterValue(value);

    if (normalized == null) {
      if (state.city == null) return;
      state = state.copyWith(clearCity: true);
      return;
    }

    if (normalized == state.city) return;
    state = state.copyWith(city: normalized);
  }

  void setSortMode(SortMode value) {
    if (value == state.sortMode) return;
    state = state.copyWith(sortMode: value);
  }

  void resetFilters() {
    final nextState = state.copyWith(
      availableSoonOnly: false,
      city: null,
      sortMode: SortMode.recommended,
    );

    if (nextState == state) return;
    state = nextState;
  }

  void resetAll() {
    final nextState = SearchFilters.initial(
      what: '',
      where: '',
    );

    if (nextState == state) return;
    state = nextState;
  }
}

final searchFiltersProvider = StateNotifierProvider.family<
    SearchFiltersController,
    SearchFilters,
    SearchSeed>(
  (ref, seed) => SearchFiltersController(
    SearchFilters.initial(
      what: seed.initialWhat,
      where: seed.initialWhere,
    ),
  ),
  name: 'searchFiltersProvider',
);

List<SearchItem> _replaceSearchItemById({
  required List<SearchItem> items,
  required String id,
  required SearchItem replacement,
}) {
  return [
    for (final item in items) item.id == id ? replacement : item,
  ];
}

final searchResultsProvider =
    FutureProvider.family<List<SearchItem>, SearchSeed>((ref, seed) async {
  final repo = ref.watch(searchRepositoryProvider);
  final filters = ref.watch(searchFiltersProvider(seed));
  final professionalProfile = ref.watch(professionalProfileProvider);

  const double? userLat = null;
  const double? userLng = null;

  final result = await repo.search(
    SearchQuery(
      what: filters.what,
      where: filters.where,
      city: filters.city,
      availableSoonOnly: filters.availableSoonOnly,
      sortMode: _mapSortMode(filters.sortMode),
      page: 1,
      pageSize: 200,
      userLatitude: userLat,
      userLongitude: userLng,
    ),
  );

  final items = result.items;
  final mergedItems = _mergeDynamicProfessionalItem(
    items: items,
    professionalProfile: professionalProfile,
  );

  return List<SearchItem>.unmodifiable(mergedItems);
}, name: 'searchResultsProvider');

final availableSearchCitiesProvider = Provider<List<String>>((ref) {
  final professionalProfile = ref.watch(professionalProfileProvider);

  final cities = <String>{};

  for (final city in MockSearchData.cities()) {
    final normalized = _normalizeOptionalFilterValue(city);
    if (normalized != null) {
      cities.add(normalized);
    }
  }

  final dynamicCity = _normalizeOptionalFilterValue(professionalProfile.city);
  if (dynamicCity != null) {
    cities.add(dynamicCity);
  }

  final sorted = cities.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return List<String>.unmodifiable(sorted);
}, name: 'availableSearchCitiesProvider');

SearchSortMode _mapSortMode(SortMode mode) {
  switch (mode) {
    case SortMode.recommended:
      return SearchSortMode.recommended;
    case SortMode.ratingDesc:
      return SearchSortMode.ratingDesc;
    case SortMode.priceAsc:
      return SearchSortMode.priceAsc;
    case SortMode.priceDesc:
      return SearchSortMode.priceDesc;
    case SortMode.distanceAsc:
      return SearchSortMode.distanceAsc;
  }
}

List<SearchItem> _mergeDynamicProfessionalItem({
  required List<SearchItem> items,
  required ProfessionalProfile professionalProfile,
}) {
  final baseProfessional = items.cast<SearchItem?>().firstWhere(
        (item) => item?.id == professionalProfile.id,
        orElse: () => null,
      );

  if (baseProfessional == null) {
    return items;
  }

  final resolved = resolvePractitionerData(
    baseItem: baseProfessional,
    profile: professionalProfile,
  );

  if (!resolved.usedProfileOverride) {
    return items;
  }

  return _replaceSearchItemById(
    items: items,
    id: professionalProfile.id,
    replacement: resolved.item,
  );
}

String _normalizeSearchText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? _normalizeOptionalFilterValue(String? value) {
  if (value == null) return null;

  final normalized = _normalizeSearchText(value);
  if (normalized.isEmpty) return null;

  return normalized;
}