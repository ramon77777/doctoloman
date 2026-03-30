import 'package:flutter/foundation.dart';

enum SearchItemType { doctor, clinic, pharmacy }

@immutable
class SearchItem {
  const SearchItem({
    required this.id,
    required this.type,
    required this.displayName,
    required this.specialty,
    required this.city,
    required this.area,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.isAvailableSoon,
    required this.priceXofMin,
    required this.priceXofMax,

    // ✅ Geo (Option A prêt)
    this.latitude,
    this.longitude,
  });

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

  /// prix en XOF
  final int priceXofMin;
  final int priceXofMax;

  /// ✅ Optionnel (si pas dispo -> null)
  final double? latitude;
  final double? longitude;

  String get locationLabel => "$area, $city";

  String get priceLabel {
    if (priceXofMin <= 0 && priceXofMax <= 0) return "Prix non communiqué";

    if (priceXofMin > 0 && priceXofMax > 0 && priceXofMin != priceXofMax) {
      // ✅ Fix: unnecessary braces in string interpolation
      return "$priceXofMin–$priceXofMax XOF";
    }

    final v = priceXofMin > 0 ? priceXofMin : priceXofMax;
    return "$v XOF";
  }
}
