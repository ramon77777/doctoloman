import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      what: what,
      where: where,
      availableSoonOnly: false,
      city: null,
      sortMode: SortMode.recommended,
    );
  }
}

@immutable
class SearchSeed {
  const SearchSeed({
    required this.initialWhat,
    required this.initialWhere,
  });

  final String initialWhat;
  final String initialWhere;
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => const MockSearchRepository(),
  name: 'searchRepositoryProvider',
);

class SearchFiltersController extends StateNotifier<SearchFilters> {
  SearchFiltersController(SearchFilters filters) : super(filters);

  void setWhat(String value) {
    state = state.copyWith(what: value);
  }

  void setWhere(String value) {
    state = state.copyWith(where: value);
  }

  void setAvailableSoonOnly(bool value) {
    state = state.copyWith(availableSoonOnly: value);
  }

  void toggleAvailableSoon() {
    state = state.copyWith(availableSoonOnly: !state.availableSoonOnly);
  }

  void setCity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      state = state.copyWith(clearCity: true);
      return;
    }

    state = state.copyWith(city: normalized);
  }

  void setSortMode(SortMode value) {
    state = state.copyWith(sortMode: value);
  }

  void resetFilters() {
    state = state.copyWith(
      availableSoonOnly: false,
      city: null,
      sortMode: SortMode.recommended,
    );
  }

  void resetAll() {
    state = SearchFilters.initial(
      what: '',
      where: '',
    );
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
      sortMode: switch (filters.sortMode) {
        SortMode.recommended => SearchSortMode.recommended,
        SortMode.ratingDesc => SearchSortMode.ratingDesc,
        SortMode.priceAsc => SearchSortMode.priceAsc,
        SortMode.priceDesc => SearchSortMode.priceDesc,
        SortMode.distanceAsc => SearchSortMode.distanceAsc,
      },
      page: 1,
      pageSize: 200,
      userLatitude: userLat,
      userLongitude: userLng,
    ),
  );

  final items = result.items;

  final baseProfessional = items.cast<SearchItem?>().firstWhere(
        (item) => item?.id == professionalProfile.id,
        orElse: () => null,
      );

  final mergedItems = baseProfessional == null
      ? items
      : _replaceSearchItemById(
          items: items,
          id: professionalProfile.id,
          replacement: resolvePractitionerData(
            baseItem: baseProfessional,
            profile: professionalProfile,
          ).item,
        );

  return List<SearchItem>.unmodifiable(mergedItems);
}, name: 'searchResultsProvider');

final availableSearchCitiesProvider = Provider<List<String>>((ref) {
  final professionalProfile = ref.watch(professionalProfileProvider);

  final cities = <String>{
    for (final city in MockSearchData.cities())
      if (city.trim().isNotEmpty) city.trim(),
  };

  final dynamicCity = professionalProfile.city.trim();
  if (dynamicCity.isNotEmpty) {
    cities.add(dynamicCity);
  }

  final sorted = cities.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return List<String>.unmodifiable(sorted);
}, name: 'availableSearchCitiesProvider');