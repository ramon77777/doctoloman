import '../domain/search_item.dart';
import '../domain/search_repository.dart';
import 'mock_search_data.dart';

const _unknownPriceSortValue = 1 << 30;

class MockSearchRepository implements SearchRepository {
  const MockSearchRepository();

  static const Duration _artificialDelay = Duration(milliseconds: 180);

  @override
  Future<SearchResultPage> search(SearchQuery query) async {
    await Future<void>.delayed(_artificialDelay);

    final normalizedWhat = _normalize(query.what);
    final normalizedWhere = _normalize(query.where);
    final normalizedCity = _normalize(query.city ?? '');

    final allItems = MockSearchData.items();

    final filtered = allItems.where((item) {
      if (!_matchesWhat(item, normalizedWhat)) return false;
      if (!_matchesWhere(item, normalizedWhere)) return false;
      if (!_matchesSelectedCity(item, normalizedCity)) return false;
      if (query.availableSoonOnly && !item.isAvailableSoon) return false;
      return true;
    }).toList();

    filtered.sort(
      (a, b) => _compareSearchItems(
        a: a,
        b: b,
        query: query,
      ),
    );

    final safePage = query.page < 1 ? 1 : query.page;
    final safePageSize = query.pageSize < 1 ? 20 : query.pageSize;
    final start = (safePage - 1) * safePageSize;
    final end = start + safePageSize;

    final paged = start >= filtered.length
        ? <SearchItem>[]
        : filtered.sublist(
            start,
            end > filtered.length ? filtered.length : end,
          );

    return SearchResultPage(
      items: List<SearchItem>.unmodifiable(paged),
      totalCount: filtered.length,
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

int _compareSearchItems({
  required SearchItem a,
  required SearchItem b,
  required SearchQuery query,
}) {
  switch (query.sortMode) {
    case SearchSortMode.recommended:
      return _compareRecommended(a, b);

    case SearchSortMode.ratingDesc:
      return _compareByRatingDesc(a, b);

    case SearchSortMode.priceAsc:
      return _compareByPriceAsc(a, b);

    case SearchSortMode.priceDesc:
      return _compareByPriceDesc(a, b);

    case SearchSortMode.distanceAsc:
      return _compareByDistanceAsc(
        a: a,
        b: b,
        userLatitude: query.userLatitude,
        userLongitude: query.userLongitude,
      );
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

int _compareByDistanceAsc({
  required SearchItem a,
  required SearchItem b,
  required double? userLatitude,
  required double? userLongitude,
}) {
  final distanceA = _distanceKmApprox(a, userLatitude, userLongitude);
  final distanceB = _distanceKmApprox(b, userLatitude, userLongitude);

  final byDistance = distanceA.compareTo(distanceB);
  if (byDistance != 0) return byDistance;

  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;

  return a.displayName.compareTo(b.displayName);
}

bool _matchesSelectedCity(SearchItem item, String normalizedCity) {
  if (normalizedCity.isEmpty) return true;
  return _normalize(item.city) == normalizedCity;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _containsNormalized(String source, String normalizedQuery) {
  if (normalizedQuery.isEmpty) return true;
  return _normalize(source).contains(normalizedQuery);
}

bool _matchesWhat(SearchItem item, String normalizedWhat) {
  if (normalizedWhat.isEmpty) return true;

  return _containsNormalized(item.displayName, normalizedWhat) ||
      _containsNormalized(item.specialty, normalizedWhat);
}

bool _matchesWhere(SearchItem item, String normalizedWhere) {
  if (normalizedWhere.isEmpty) return true;

  return _containsNormalized(item.city, normalizedWhere) ||
      _containsNormalized(item.area, normalizedWhere) ||
      _containsNormalized(item.address, normalizedWhere) ||
      _containsNormalized(item.locationLabel, normalizedWhere);
}

int _effectivePrice(SearchItem item) {
  if (item.priceXofMin <= 0 && item.priceXofMax <= 0) {
    return _unknownPriceSortValue;
  }

  if (item.priceXofMin > 0) return item.priceXofMin;
  if (item.priceXofMax > 0) return item.priceXofMax;

  return _unknownPriceSortValue;
}

double _distanceKmApprox(SearchItem item, double? lat, double? lng) {
  if (lat == null || lng == null) return double.infinity;
  if (item.latitude == null || item.longitude == null) return double.infinity;

  final dLat = (item.latitude! - lat).abs();
  final dLng = (item.longitude! - lng).abs();

  return (dLat + dLng) * 111;
}