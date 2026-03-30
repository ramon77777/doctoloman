import 'package:flutter/foundation.dart';

@immutable
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.city,
    required this.area,
    required this.address,
    required this.phone,
    required this.openingHours,
    required this.isOnDuty,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;

  final String city;
  final String area;
  final String address;

  final String phone;
  final String openingHours;

  final bool isOnDuty;

  /// Position GPS (nullable si non dispo)
  final double? latitude;
  final double? longitude;

  String get locationLabel => '$area, $city';

  bool get hasCoordinates => latitude != null && longitude != null;
}