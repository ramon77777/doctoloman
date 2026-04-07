import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/mock_pharmacies_data.dart';
import '../data/mock_pharmacy_repository.dart';
import '../domain/pharmacy.dart';
import '../domain/pharmacy_repository.dart';

enum PharmacySortMode {
  recommended,
  distanceAsc,
}

@immutable
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;
}

@immutable
class PharmacyWithDistance {
  const PharmacyWithDistance({
    required this.pharmacy,
    required this.distanceKm,
  });

  static const double nearbyRadiusKm = 5.0;

  final Pharmacy pharmacy;

  /// null => distance inconnue
  final double? distanceKm;

  bool get hasDistance => distanceKm != null;
  bool get isNear => distanceKm != null && distanceKm! <= nearbyRadiusKm;
}

@immutable
class PharmacyFilters {
  const PharmacyFilters({
    required this.onDutyOnly,
    required this.useMyLocation,
    required this.sortMode,
    required this.query,
    required this.city,
  });

  final bool onDutyOnly;
  final bool useMyLocation;
  final PharmacySortMode sortMode;
  final String query;
  final String? city;

  PharmacyFilters copyWith({
    bool? onDutyOnly,
    bool? useMyLocation,
    PharmacySortMode? sortMode,
    String? query,
    String? city,
    bool clearCity = false,
  }) {
    return PharmacyFilters(
      onDutyOnly: onDutyOnly ?? this.onDutyOnly,
      useMyLocation: useMyLocation ?? this.useMyLocation,
      sortMode: sortMode ?? this.sortMode,
      query: query ?? this.query,
      city: clearCity ? null : (city ?? this.city),
    );
  }

  static const initial = PharmacyFilters(
    onDutyOnly: false,
    useMyLocation: false,
    sortMode: PharmacySortMode.recommended,
    query: '',
    city: null,
  );
}

class PharmacyFiltersController extends StateNotifier<PharmacyFilters> {
  PharmacyFiltersController() : super(PharmacyFilters.initial);

  void setOnDutyOnly(bool value) {
    state = state.copyWith(onDutyOnly: value);
  }

  void toggleOnDuty() {
    state = state.copyWith(onDutyOnly: !state.onDutyOnly);
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void clearQuery() {
    state = state.copyWith(query: '');
  }

  void setCity(String? city) {
    final normalized = city?.trim();
    if (normalized == null || normalized.isEmpty) {
      state = state.copyWith(clearCity: true);
      return;
    }

    state = state.copyWith(city: normalized);
  }

  void setUseMyLocation(bool value) {
    state = state.copyWith(
      useMyLocation: value,
      sortMode:
          value ? PharmacySortMode.distanceAsc : PharmacySortMode.recommended,
    );
  }

  void setSortMode(PharmacySortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void resetAll() {
    state = PharmacyFilters.initial;
  }
}

@immutable
class PharmaciesResultView {
  const PharmaciesResultView({
    required this.items,
    required this.nearbyItems,
    required this.otherItems,
    required this.totalCount,
    required this.nearbyCount,
    required this.onDutyCount,
    required this.hasDistanceData,
    required this.selectedCity,
    required this.availableCities,
    required this.locationConsentGranted,
  });

  final List<PharmacyWithDistance> items;
  final List<PharmacyWithDistance> nearbyItems;
  final List<PharmacyWithDistance> otherItems;

  final int totalCount;
  final int nearbyCount;
  final int onDutyCount;
  final bool hasDistanceData;

  final String? selectedCity;
  final List<String> availableCities;
  final bool locationConsentGranted;
}

final pharmacyRepositoryProvider = Provider<PharmacyRepository>(
  (ref) => const MockPharmacyRepository(),
  name: 'pharmacyRepositoryProvider',
);

final locationConsentProvider = StateProvider<bool>(
  (ref) => false,
  name: 'locationConsentProvider',
);

final pharmacyFiltersProvider =
    StateNotifierProvider<PharmacyFiltersController, PharmacyFilters>(
  (ref) => PharmacyFiltersController(),
  name: 'pharmacyFiltersProvider',
);

final pharmacyCitiesProvider = Provider<List<String>>(
  (ref) {
    final cities = MockPharmaciesData.cities()
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return List<String>.unmodifiable(cities);
  },
  name: 'pharmacyCitiesProvider',
);

final userLocationProvider = FutureProvider<Position?>(
  (ref) async {
    final consent = ref.watch(locationConsentProvider);
    final filters = ref.watch(pharmacyFiltersProvider);

    if (!consent || !filters.useMyLocation) {
      return null;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 6),
    );
  },
  name: 'userLocationProvider',
);

final pharmaciesResultsProvider = FutureProvider<PharmaciesResultView>(
  (ref) async {
    final repo = ref.watch(pharmacyRepositoryProvider);
    final filters = ref.watch(pharmacyFiltersProvider);
    final availableCities = ref.watch(pharmacyCitiesProvider);
    final consent = ref.watch(locationConsentProvider);
    final position = await ref.watch(userLocationProvider.future);

    final all = await repo.getAll();

    final filtered = _applyPharmacyFilters(
      items: all,
      filters: filters,
    );

    final withDistance = _attachDistance(
      items: filtered,
      position: position,
    );

    final sorted = _sortPharmacies(
      items: withDistance,
      sortMode: filters.sortMode,
      hasUserPosition: position != null,
    );

    final nearbyItems = sorted.where((item) => item.isNear).toList();
    final otherItems = sorted.where((item) => !item.isNear).toList();
    final hasDistanceData = sorted.any((item) => item.hasDistance);
    final onDutyCount =
        sorted.where((item) => item.pharmacy.isOnDuty).length;

    return PharmaciesResultView(
      items: List<PharmacyWithDistance>.unmodifiable(sorted),
      nearbyItems: List<PharmacyWithDistance>.unmodifiable(nearbyItems),
      otherItems: List<PharmacyWithDistance>.unmodifiable(otherItems),
      totalCount: sorted.length,
      nearbyCount: nearbyItems.length,
      onDutyCount: onDutyCount,
      hasDistanceData: hasDistanceData,
      selectedCity: filters.city,
      availableCities: availableCities,
      locationConsentGranted: consent,
    );
  },
  name: 'pharmaciesResultsProvider',
);

final pharmaciesOnDutyProvider = FutureProvider<List<PharmacyWithDistance>>(
  (ref) async {
    final result = await ref.watch(pharmaciesResultsProvider.future);
    return List<PharmacyWithDistance>.unmodifiable(
      result.items.where((item) => item.pharmacy.isOnDuty),
    );
  },
  name: 'pharmaciesOnDutyProvider',
);

List<Pharmacy> _applyPharmacyFilters({
  required List<Pharmacy> items,
  required PharmacyFilters filters,
}) {
  final normalizedQuery = _norm(filters.query);
  final selectedCity = filters.city?.trim();

  return items.where((pharmacy) {
    if (filters.onDutyOnly && !pharmacy.isOnDuty) {
      return false;
    }

    if (selectedCity != null && selectedCity.isNotEmpty) {
      if (_norm(pharmacy.city) != _norm(selectedCity)) {
        return false;
      }
    }

    if (normalizedQuery.isNotEmpty) {
      final haystack = _norm(
        '${pharmacy.name} ${pharmacy.city} ${pharmacy.area} ${pharmacy.address}',
      );

      if (!haystack.contains(normalizedQuery)) {
        return false;
      }
    }

    return true;
  }).toList();
}

List<PharmacyWithDistance> _attachDistance({
  required List<Pharmacy> items,
  required Position? position,
}) {
  return items.map((pharmacy) {
    if (position == null || !pharmacy.hasCoordinates) {
      return PharmacyWithDistance(
        pharmacy: pharmacy,
        distanceKm: null,
      );
    }

    return PharmacyWithDistance(
      pharmacy: pharmacy,
      distanceKm: _haversineKm(
        LatLng(position.latitude, position.longitude),
        LatLng(pharmacy.latitude!, pharmacy.longitude!),
      ),
    );
  }).toList();
}

List<PharmacyWithDistance> _sortPharmacies({
  required List<PharmacyWithDistance> items,
  required PharmacySortMode sortMode,
  required bool hasUserPosition,
}) {
  final sorted = [...items];

  sorted.sort((a, b) {
    if (sortMode == PharmacySortMode.distanceAsc && hasUserPosition) {
      final byDistance = _compareNullableDistance(a.distanceKm, b.distanceKm);
      if (byDistance != 0) {
        return byDistance;
      }
    }

    if (a.pharmacy.isOnDuty != b.pharmacy.isOnDuty) {
      return a.pharmacy.isOnDuty ? -1 : 1;
    }

    final byName = a.pharmacy.name.compareTo(b.pharmacy.name);
    if (byName != 0) {
      return byName;
    }

    return a.pharmacy.city.compareTo(b.pharmacy.city);
  });

  return sorted;
}

int _compareNullableDistance(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

String _norm(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ');

double _haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;

  final dLat = _deg2rad(b.lat - a.lat);
  final dLng = _deg2rad(b.lng - a.lng);

  final lat1 = _deg2rad(a.lat);
  final lat2 = _deg2rad(b.lat);

  final haversine = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);

  final arc = 2 * atan2(sqrt(haversine), sqrt(1 - haversine));
  return earthRadiusKm * arc;
}

double _deg2rad(double deg) => deg * (pi / 180.0);

final pharmacyByIdProvider =
    FutureProvider.family<Pharmacy?, String>((ref, pharmacyId) async {
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getById(pharmacyId);
}, name: 'pharmacyByIdProvider');