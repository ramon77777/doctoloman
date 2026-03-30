import 'search_item.dart';

enum SearchSortMode {
  recommended,
  ratingDesc,
  priceAsc,
  priceDesc,
  distanceAsc,
}

class SearchQuery {
  const SearchQuery({
    this.what = '',
    this.where = '',
    this.city,
    this.availableSoonOnly = false,
    this.sortMode = SearchSortMode.recommended,
    this.page = 1,
    this.pageSize = 20,
    this.userLatitude,
    this.userLongitude,
  });

  final String what;
  final String where;
  final String? city;
  final bool availableSoonOnly;
  final SearchSortMode sortMode;
  final int page;
  final int pageSize;
  final double? userLatitude;
  final double? userLongitude;
}

class SearchResultPage {
  const SearchResultPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<SearchItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
}

abstract class SearchRepository {
  Future<SearchResultPage> search(SearchQuery query);

  Future<SearchItem?> getById(String id);
}