import 'package:flutter/foundation.dart';

enum SearchItemType { doctor, clinic, pharmacy }

@immutable
class SearchItem {
  SearchItem({
    required String id,
    required this.type,
    required String displayName,
    required String specialty,
    required String city,
    required String area,
    required String address,
    required double rating,
    required int reviewCount,
    required this.isVerified,
    required this.isAvailableSoon,
    required int priceXofMin,
    required int priceXofMax,
    this.latitude,
    this.longitude,
  })  : id = _cleanText(id),
        displayName = _cleanText(displayName),
        specialty = _cleanText(specialty),
        city = _cleanText(city),
        area = _cleanText(area),
        address = _cleanText(address),
        rating = _sanitizeRating(rating),
        reviewCount = reviewCount < 0 ? 0 : reviewCount,
        priceXofMin = _sanitizePrice(priceXofMin),
        priceXofMax = _sanitizePrice(priceXofMax);

  final String id;
  final SearchItemType type;

  final String displayName;
  final String specialty;

  final String city;
  final String area;
  final String address;

  final double rating;
  final int reviewCount;

  final bool isVerified;
  final bool isAvailableSoon;

  final int priceXofMin;
  final int priceXofMax;

  final double? latitude;
  final double? longitude;

  // =========================
  // HELPERS MÉTIER
  // =========================

  bool get hasLocation => city.isNotEmpty || area.isNotEmpty;
  bool get hasAddress => address.isNotEmpty;
  bool get hasGeo => latitude != null && longitude != null;

  String get locationLabel {
    if (area.isEmpty && city.isEmpty) return 'Localisation non renseignée';
    if (area.isEmpty) return city;
    if (city.isEmpty) return area;
    return '$area, $city';
  }

  String get priceLabel {
    if (priceXofMin <= 0 && priceXofMax <= 0) {
      return 'Prix non communiqué';
    }

    if (priceXofMin > 0 &&
        priceXofMax > 0 &&
        priceXofMin != priceXofMax) {
      final min = priceXofMin < priceXofMax ? priceXofMin : priceXofMax;
      final max = priceXofMin < priceXofMax ? priceXofMax : priceXofMin;
      return '$min–$max XOF';
    }

    final v = priceXofMin > 0 ? priceXofMin : priceXofMax;
    return '$v XOF';
  }

  // =========================
  // COPY / EQUALITY
  // =========================

  SearchItem copyWith({
    String? id,
    SearchItemType? type,
    String? displayName,
    String? specialty,
    String? city,
    String? area,
    String? address,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    bool? isAvailableSoon,
    int? priceXofMin,
    int? priceXofMax,
    double? latitude,
    double? longitude,
  }) {
    return SearchItem(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      specialty: specialty ?? this.specialty,
      city: city ?? this.city,
      area: area ?? this.area,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      isAvailableSoon: isAvailableSoon ?? this.isAvailableSoon,
      priceXofMin: priceXofMin ?? this.priceXofMin,
      priceXofMax: priceXofMax ?? this.priceXofMax,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchItem &&
        other.id == id &&
        other.type == type &&
        other.displayName == displayName &&
        other.specialty == specialty &&
        other.city == city &&
        other.area == area &&
        other.address == address &&
        other.rating == rating &&
        other.reviewCount == reviewCount &&
        other.isVerified == isVerified &&
        other.isAvailableSoon == isAvailableSoon &&
        other.priceXofMin == priceXofMin &&
        other.priceXofMax == priceXofMax &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      displayName,
      specialty,
      city,
      area,
      address,
      rating,
      reviewCount,
      isVerified,
      isAvailableSoon,
      priceXofMin,
      priceXofMax,
      latitude,
      longitude,
    );
  }

  @override
  String toString() {
    return 'SearchItem(id: $id, name: $displayName, specialty: $specialty)';
  }

  // =========================
  // NORMALISATION
  // =========================

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _sanitizePrice(int value) {
    return value < 0 ? 0 : value;
  }

  static double _sanitizeRating(double value) {
    if (value < 0) return 0;
    if (value > 5) return 5;
    return value;
  }
}