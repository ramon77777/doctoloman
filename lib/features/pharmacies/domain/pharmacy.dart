import 'package:flutter/foundation.dart';

@immutable
class Pharmacy {
  Pharmacy({
    required String id,
    required String name,
    required String city,
    required String area,
    required String address,
    required String phone,
    required String openingHours,
    required this.isOnDuty,
    double? latitude,
    double? longitude,
  })  : id = _cleanText(id),
        name = _cleanText(name),
        city = _cleanText(city),
        area = _cleanText(area),
        address = _cleanText(address),
        phone = _cleanText(phone),
        openingHours = _cleanText(openingHours),
        latitude = _normalizeLatitude(latitude),
        longitude = _normalizeLongitude(longitude);

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

  String get locationLabel {
    final parts = <String>[
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
    ];

    if (parts.isEmpty) return 'Localisation non renseignée';
    return parts.join(', ');
  }

  String get fullAddress {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
    ];

    if (parts.isEmpty) return 'Adresse non renseignée';
    return parts.join(' • ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasPhone => phone.isNotEmpty;
  bool get hasOpeningHours => openingHours.isNotEmpty;

  Pharmacy copyWith({
    String? id,
    String? name,
    String? city,
    String? area,
    String? address,
    String? phone,
    String? openingHours,
    bool? isOnDuty,
    double? latitude,
    double? longitude,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearCoordinates = false,
  }) {
    return Pharmacy(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      area: area ?? this.area,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      latitude: clearCoordinates || clearLatitude
          ? null
          : (latitude ?? this.latitude),
      longitude: clearCoordinates || clearLongitude
          ? null
          : (longitude ?? this.longitude),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'area': area,
      'address': address,
      'phone': phone,
      'openingHours': openingHours,
      'isOnDuty': isOnDuty,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Pharmacy.fromMap(Map<String, dynamic> map) {
    return Pharmacy(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      area: (map['area'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      openingHours: (map['openingHours'] as String?) ?? '',
      isOnDuty: (map['isOnDuty'] as bool?) ?? false,
      latitude: _readDouble(map['latitude']),
      longitude: _readDouble(map['longitude']),
    );
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static double? _readDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static double? _normalizeLatitude(double? value) {
    if (value == null) return null;
    if (value < -90 || value > 90) return null;
    return value;
  }

  static double? _normalizeLongitude(double? value) {
    if (value == null) return null;
    if (value < -180 || value > 180) return null;
    return value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Pharmacy &&
        other.id == id &&
        other.name == name &&
        other.city == city &&
        other.area == area &&
        other.address == address &&
        other.phone == phone &&
        other.openingHours == openingHours &&
        other.isOnDuty == isOnDuty &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      city,
      area,
      address,
      phone,
      openingHours,
      isOnDuty,
      latitude,
      longitude,
    );
  }

  @override
  String toString() {
    return 'Pharmacy(id: $id, name: $name, city: $city, isOnDuty: $isOnDuty)';
  }
}