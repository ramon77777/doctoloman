import '../domain/search_item.dart';
import '../domain/search_repository.dart';
import 'mock_search_data.dart';

class MockSearchRepository implements SearchRepository {
  const MockSearchRepository();

  static const Duration _artificialDelay = Duration(milliseconds: 180);

  @override
  Future<SearchResultPage> search(SearchQuery query) async {
    await Future<void>.delayed(_artificialDelay);

    final all = MockSearchData.items();

    final filtered = all.where((item) {
      if (!_matchesWhat(item, query.what)) return false;
      if (!_matchesWhere(item, query.where)) return false;

      final selectedCity = query.city?.trim();
      if (selectedCity != null && selectedCity.isNotEmpty) {
        if (_normalize(item.city) != _normalize(selectedCity)) {
          return false;
        }
      }

      if (query.availableSoonOnly && !item.isAvailableSoon) {
        return false;
      }

      return true;
    }).toList();

    final sorted = [...filtered]..sort((a, b) {
      switch (query.sortMode) {
        case SearchSortMode.recommended:
          final verified = (b.isVerified ? 1 : 0) - (a.isVerified ? 1 : 0);
          if (verified != 0) return verified;

          final availableSoon =
              (b.isAvailableSoon ? 1 : 0) - (a.isAvailableSoon ? 1 : 0);
          if (availableSoon != 0) return availableSoon;

          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;

          return b.reviewCount.compareTo(a.reviewCount);

        case SearchSortMode.ratingDesc:
          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;
          return b.reviewCount.compareTo(a.reviewCount);

        case SearchSortMode.priceAsc:
          final byPrice = _effectivePrice(a).compareTo(_effectivePrice(b));
          if (byPrice != 0) return byPrice;
          return b.rating.compareTo(a.rating);

        case SearchSortMode.priceDesc:
          final byPrice = _effectivePrice(b).compareTo(_effectivePrice(a));
          if (byPrice != 0) return byPrice;
          return b.rating.compareTo(a.rating);

        case SearchSortMode.distanceAsc:
          final da = _distanceKmApprox(
            a,
            query.userLatitude,
            query.userLongitude,
          );
          final db = _distanceKmApprox(
            b,
            query.userLatitude,
            query.userLongitude,
          );
          final byDistance = da.compareTo(db);
          if (byDistance != 0) return byDistance;
          return b.rating.compareTo(a.rating);
      }
    });

    final safePage = query.page < 1 ? 1 : query.page;
    final safePageSize = query.pageSize < 1 ? 20 : query.pageSize;
    final start = (safePage - 1) * safePageSize;
    final end = start + safePageSize;

    final paged = start >= sorted.length
        ? <SearchItem>[]
        : sorted.sublist(start, end > sorted.length ? sorted.length : end);

    return SearchResultPage(
      items: List<SearchItem>.unmodifiable(paged),
      totalCount: sorted.length,
      page: safePage,
      pageSize: safePageSize,
    );
  }

  @override
  Future<SearchItem?> getById(String id) async {
    await Future<void>.delayed(_artificialDelay);

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;

    for (final item in MockSearchData.items()) {
      if (item.id == normalizedId) {
        return item;
      }
    }
    return null;
  }
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _containsNormalized(String source, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) return true;
  return _normalize(source).contains(normalizedQuery);
}

bool _matchesWhat(SearchItem item, String what) {
  final normalized = _normalize(what);
  if (normalized.isEmpty) return true;

  return _containsNormalized(item.displayName, normalized) ||
      _containsNormalized(item.specialty, normalized);
}

bool _matchesWhere(SearchItem item, String where) {
  final normalized = _normalize(where);
  if (normalized.isEmpty) return true;

  return _containsNormalized(item.city, normalized) ||
      _containsNormalized(item.area, normalized) ||
      _containsNormalized(item.address, normalized) ||
      _containsNormalized(item.locationLabel, normalized);
}

int _effectivePrice(SearchItem item) {
  if (item.priceXofMin <= 0 && item.priceXofMax <= 0) {
    return 1 << 30;
  }
  if (item.priceXofMin > 0) {
    return item.priceXofMin;
  }
  if (item.priceXofMax > 0) {
    return item.priceXofMax;
  }
  return 1 << 30;
}

double _distanceKmApprox(SearchItem item, double? lat, double? lng) {
  if (lat == null || lng == null) return double.infinity;
  if (item.latitude == null || item.longitude == null) return double.infinity;

  final dLat = (item.latitude! - lat).abs();
  final dLng = (item.longitude! - lng).abs();
  return (dLat + dLng) * 111;
}