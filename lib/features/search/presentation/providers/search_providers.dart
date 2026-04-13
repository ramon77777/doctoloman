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

final searchResultsProvider =
    FutureProvider.family<List<SearchItem>, SearchSeed>((ref, seed) async {
  final repo = ref.watch(searchRepositoryProvider);
  final filters = ref.watch(searchFiltersProvider(seed));
  final allProfessionalProfiles =
      await ref.watch(allProfessionalProfilesProvider.future);

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

  final mergedItems = _mergeDynamicProfessionalItems(
    items: result.items,
    professionalProfiles: allProfessionalProfiles,
    filters: filters,
  );

  final sorted = [...mergedItems]
    ..sort(
      (a, b) => _compareSearchItemsForUi(
        a: a,
        b: b,
        sortMode: filters.sortMode,
      ),
    );

  return List<SearchItem>.unmodifiable(sorted);
}, name: 'searchResultsProvider');

final availableSearchCitiesProvider = Provider<List<String>>((ref) {
  final allProfessionalProfilesAsync = ref.watch(allProfessionalProfilesProvider);
  final allProfessionalProfiles =
      allProfessionalProfilesAsync.valueOrNull ??
          const <ProfessionalProfile>[];

  final cities = <String>{};

  for (final city in MockSearchData.cities()) {
    final normalized = _normalizeOptionalFilterValue(city);
    if (normalized != null) {
      cities.add(normalized);
    }
  }

  for (final profile in allProfessionalProfiles) {
    final dynamicCity = _normalizeOptionalFilterValue(profile.city);
    if (dynamicCity != null) {
      cities.add(dynamicCity);
    }
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

List<SearchItem> _mergeDynamicProfessionalItems({
  required List<SearchItem> items,
  required List<ProfessionalProfile> professionalProfiles,
  required SearchFilters filters,
}) {
  final mergedById = <String, SearchItem>{
    for (final item in items) item.id: item,
  };

  for (final profile in professionalProfiles) {
    final fallbackBaseItem = _buildSearchItemFromProfessionalProfile(profile);

    final existingBaseItem = mergedById[profile.id] ?? fallbackBaseItem;

    final resolved = resolvePractitionerData(
      baseItem: existingBaseItem,
      profile: profile,
    );

    final candidate = resolved.item;

    if (!_matchesSearchFilters(candidate, filters)) {
      if (mergedById.containsKey(profile.id) &&
          !_matchesSearchFilters(mergedById[profile.id]!, filters)) {
        mergedById.remove(profile.id);
      }
      continue;
    }

    mergedById[profile.id] = candidate;
  }

  return mergedById.values.toList();
}

SearchItem _buildSearchItemFromProfessionalProfile(ProfessionalProfile profile) {
  final (minPrice, maxPrice) =
      extractPriceRange(profile.consultationFeeLabel);

  return SearchItem(
    id: profile.id,
    type: SearchItemType.doctor,
    displayName: profile.displayName.trim().isEmpty
        ? 'Professionnel de santé'
        : profile.displayName,
    specialty: profile.specialty.trim().isEmpty
        ? 'Professionnel de santé'
        : profile.specialty,
    city: profile.city,
    area: profile.area,
    address: profile.address,
    rating: 0,
    reviewCount: 0,
    isVerified: profile.isVerified,
    isAvailableSoon: true,
    priceXofMin: minPrice,
    priceXofMax: maxPrice,
  );
}

bool _matchesSearchFilters(SearchItem item, SearchFilters filters) {
  final normalizedWhat = _normalize(item.displayName);
  final normalizedSpecialty = _normalize(item.specialty);
  final normalizedWhere = _normalize(
    '${item.city} ${item.area} ${item.address} ${item.locationLabel}',
  );

  final queryWhat = _normalize(filters.what);
  final queryWhere = _normalize(filters.where);
  final queryCity = _normalize(filters.city ?? '');

  final matchesWhat = queryWhat.isEmpty ||
      normalizedWhat.contains(queryWhat) ||
      normalizedSpecialty.contains(queryWhat);

  final matchesWhere = queryWhere.isEmpty || normalizedWhere.contains(queryWhere);

  final matchesCity =
      queryCity.isEmpty || _normalize(item.city) == queryCity;

  final matchesAvailableSoon =
      !filters.availableSoonOnly || item.isAvailableSoon;

  return matchesWhat &&
      matchesWhere &&
      matchesCity &&
      matchesAvailableSoon;
}

int _compareSearchItemsForUi({
  required SearchItem a,
  required SearchItem b,
  required SortMode sortMode,
}) {
  switch (sortMode) {
    case SortMode.recommended:
      return _compareRecommended(a, b);
    case SortMode.ratingDesc:
      return _compareByRatingDesc(a, b);
    case SortMode.priceAsc:
      return _compareByPriceAsc(a, b);
    case SortMode.priceDesc:
      return _compareByPriceDesc(a, b);
    case SortMode.distanceAsc:
      return a.displayName.compareTo(b.displayName);
  }
}

int _compareRecommended(SearchItem a, SearchItem b) {
  final verified = (b.isVerified ? 1 : 0) - (a.isVerified ? 1 : 0);
  if (verified != 0) return verified;

  final availableSoon =
      (b.isAvailableSoon ? 1 : 0) - (a.isAvailableSoon ? 1 : 0);
  if (availableSoon != 0) return availableSoon;

  final rating = b.rating.compareTo(a.rating);
  if (rating != 0) return rating;

  final reviewCount = b.reviewCount.compareTo(a.reviewCount);
  if (reviewCount != 0) return reviewCount;

  return a.displayName.compareTo(b.displayName);
}

int _compareByRatingDesc(SearchItem a, SearchItem b) {
  final rating = b.rating.compareTo(a.rating);
  if (rating != 0) return rating;

  final reviewCount = b.reviewCount.compareTo(a.reviewCount);
  if (reviewCount != 0) return reviewCount;

  return a.displayName.compareTo(b.displayName);
}

int _compareByPriceAsc(SearchItem a, SearchItem b) {
  final byPrice = _effectivePrice(a).compareTo(_effectivePrice(b));
  if (byPrice != 0) return byPrice;

  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;

  return a.displayName.compareTo(b.displayName);
}

int _compareByPriceDesc(SearchItem a, SearchItem b) {
  final byPrice = _effectivePrice(b).compareTo(_effectivePrice(a));
  if (byPrice != 0) return byPrice;

  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;

  return a.displayName.compareTo(b.displayName);
}

int _effectivePrice(SearchItem item) {
  if (item.priceXofMin <= 0 && item.priceXofMax <= 0) {
    return 1 << 30;
  }

  if (item.priceXofMin > 0) return item.priceXofMin;
  if (item.priceXofMax > 0) return item.priceXofMax;

  return 1 << 30;
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

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}